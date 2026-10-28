"""실제 파일을 바꾸지 않고 잘못된 보드 설정의 거부 여부를 검사한다."""

import contextlib
import io
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest.mock import patch

import check_repository


class RepositoryChecksTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root = Path(check_repository.__file__).resolve().parents[1]
        cls.project_xml = (cls.root / "fpga-microwave-oven.xpr").read_text(
            encoding="utf-8"
        )
        cls.xdc = (
            cls.root / "fpga-microwave-oven.srcs/constrs_1/new/microwave_basys3.xdc"
        )

    def check_project(self, mutate):
        tree = ET.ElementTree(ET.fromstring(self.project_xml))
        mutate(tree)
        with patch.object(check_repository.ET, "parse", return_value=tree):
            with contextlib.redirect_stdout(io.StringIO()):
                check_repository.main()

    def check_xdc(self, transform):
        original_read = Path.read_text

        def read_text(path, *args, **kwargs):
            text = original_read(path, *args, **kwargs)
            return transform(text) if path == self.xdc else text

        with patch.object(Path, "read_text", read_text):
            with contextlib.redirect_stdout(io.StringIO()):
                check_repository.main()

    def test_current_repository(self):
        self.check_project(lambda tree: None)

    def test_wrong_part(self):
        with self.assertRaisesRegex(ValueError, "Unexpected FPGA part"):
            self.check_project(
                lambda tree: tree.find('.//Configuration/Option[@Name="Part"]').set(
                    "Val", "xc7a100tcsg324-1"
                )
            )

    def test_wrong_design_top(self):
        with self.assertRaisesRegex(ValueError, "Board Design Top mismatch"):
            self.check_project(
                lambda tree: tree.find(
                    './/FileSet[@Name="sources_1"]/Config/Option[@Name="TopModule"]'
                ).set("Val", "microwave_controller")
            )

    def test_unit_simulation_top_allowed(self):
        self.check_project(
            lambda tree: tree.find(
                './/FileSet[@Name="sim_1"]/Config/Option[@Name="TopModule"]'
            ).set("Val", "tb_servo_controller")
        )

    def test_commented_pin(self):
        with self.assertRaisesRegex(ValueError, "Top/XDC port coverage mismatch"):
            self.check_xdc(
                lambda text: text.replace(
                    "set_property -dict {PACKAGE_PIN J1 ",
                    "#set_property -dict {PACKAGE_PIN J1 ",
                    1,
                )
            )

    def test_commented_clock(self):
        with self.assertRaisesRegex(ValueError, "exactly one active board clock"):
            self.check_xdc(
                lambda text: text.replace("create_clock ", "#create_clock ", 1)
            )

    def test_wrong_clock_period(self):
        with self.assertRaisesRegex(ValueError, "Board clock must be 100 MHz"):
            self.check_xdc(
                lambda text: text.replace("-period 10.000", "-period 20.000", 1)
            )

    def test_extra_clock(self):
        with self.assertRaisesRegex(ValueError, "exactly one active board clock"):
            self.check_xdc(
                lambda text: (
                    text + "\ncreate_clock -name extra -period 20 [get_ports clk]\n"
                )
            )

    def test_commented_duplicate_pin_allowed(self):
        self.check_xdc(
            lambda text: (
                text
                + "\n#set_property -dict {PACKAGE_PIN J1 IOSTANDARD LVCMOS33} [get_ports {motor_pwm}]\n"
            )
        )


if __name__ == "__main__":
    unittest.main()
