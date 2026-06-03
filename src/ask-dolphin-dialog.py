#!/usr/bin/env python3
"""
ask-dolphin-dialog.py — PyQt5 dialog for selecting/entering an AI query.
Used from ask-dolphin.sh.

CLI arguments: preset queries.
Stdin: a string describing selected files (optional).
Stdout: the selected/entered query.
Exit code: 0 — OK, 1 — Cancel.
"""

import sys
from PyQt5.QtWidgets import (
    QApplication, QDialog, QVBoxLayout, QPushButton,
    QLineEdit, QLabel, QDialogButtonBox, QFrame, QSizePolicy,
)
from PyQt5.QtCore import Qt
from PyQt5.QtGui import QIcon, QFont


# --- QSS style for KDE Breeze ---
STYLE = """
QDialog {
    background-color: #eff0f1;
}

QFrame#headerFrame {
    background-color: #1d99f3;
    border-radius: 6px;
    padding: 12px;
}

QLabel#headerTitle {
    color: #ffffff;
    font-size: 16px;
    font-weight: bold;
}

QLabel#headerSubtitle {
    color: #d6eaff;
    font-size: 12px;
}

QFrame#fileFrame {
    background-color: #fcfcfc;
    border: 1px solid #bdc3c7;
    border-radius: 5px;
    padding: 10px;
}

QLabel#fileLabel {
    color: #31363b;
    font-size: 12px;
    line-height: 1.4;
}

QPushButton {
    background-color: #fcfcfc;
    border: 1px solid #bdc3c7;
    border-radius: 4px;
    padding: 8px 16px;
    font-size: 12px;
    color: #31363b;
    min-height: 20px;
}

QPushButton:hover {
    background-color: #d6eaff;
    border-color: #1d99f3;
    color: #1d99f3;
}

QPushButton:pressed {
    background-color: #b3d9f9;
    border-color: #1a7dc9;
}

QLineEdit {
    background-color: #fcfcfc;
    border: 1px solid #bdc3c7;
    border-radius: 4px;
    padding: 8px 12px;
    font-size: 13px;
    color: #31363b;
    min-height: 22px;
}

QLineEdit:focus {
    border-color: #1d99f3;
    background-color: #ffffff;
}

QDialogButtonBox QPushButton {
    min-width: 80px;
    min-height: 16px;
    padding: 6px 20px;
    font-size: 12px;
}

#okButton {
    background-color: #1d99f3;
    border-color: #1a7dc9;
    color: #ffffff;
    font-weight: bold;
}

#okButton:hover {
    background-color: #2ea6ff;
}

#okButton:pressed {
    background-color: #1a7dc9;
}
"""


class AskDialog(QDialog):
    def __init__(self, presets, file_info):
        super().__init__()
        self.setWindowTitle("🤖  Ask AI")
        self.setWindowIcon(QIcon.fromTheme("utilities-terminal"))
        self.setMinimumWidth(640)
        self.setModal(True)
        self.setStyleSheet(STYLE)

        layout = QVBoxLayout(self)
        layout.setSpacing(12)
        layout.setContentsMargins(20, 20, 20, 20)

        # --- Header ---
        header = QFrame()
        header.setObjectName("headerFrame")
        hdr_layout = QVBoxLayout(header)
        hdr_layout.setContentsMargins(16, 12, 16, 12)
        hdr_layout.setSpacing(2)

        title = QLabel("🤖  Ask AI")
        title.setObjectName("headerTitle")
        hdr_layout.addWidget(title)

        if file_info:
            sub = QLabel(file_info.replace("\\n", "  ·  "))
            sub.setObjectName("headerSubtitle")
            sub.setWordWrap(True)
            hdr_layout.addWidget(sub)

        layout.addWidget(header)

        # --- File info card (if multiple lines) ---
        if file_info and "\\n" in file_info:
            file_frame = QFrame()
            file_frame.setObjectName("fileFrame")
            fl_layout = QVBoxLayout(file_frame)
            fl_layout.setContentsMargins(12, 8, 12, 8)

            file_label = QLabel(file_info)
            file_label.setObjectName("fileLabel")
            file_label.setWordWrap(True)
            file_label.setTextInteractionFlags(Qt.TextSelectableByMouse)
            fl_layout.addWidget(file_label)

            layout.addWidget(file_frame)

        # --- Preset buttons ---
        presets_label = QLabel("Quick queries:")
        presets_label.setStyleSheet(
            "color: #62686e; font-size: 11px; font-weight: bold; "
            "padding: 0; margin: 0;"
        )
        layout.addWidget(presets_label)

        for preset in presets:
            btn = QPushButton(preset)
            btn.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
            btn.setMinimumHeight(40)
            btn.clicked.connect(lambda checked, p=preset: self.on_preset(p))
            layout.addWidget(btn)

        # --- Custom input field ---
        input_label = QLabel("Or type your query:")
        input_label.setStyleSheet(
            "color: #62686e; font-size: 11px; font-weight: bold; "
            "padding: 0; margin-top: 4px;"
        )
        layout.addWidget(input_label)

        self.input_field = QLineEdit()
        self.input_field.setPlaceholderText("Your question…")
        layout.addWidget(self.input_field)

        # --- OK / Cancel buttons ---
        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        ok_btn = buttons.button(QDialogButtonBox.Ok)
        ok_btn.setObjectName("okButton")
        ok_btn.setText("Send")
        buttons.button(QDialogButtonBox.Cancel).setText("Cancel")
        buttons.accepted.connect(self.on_ok)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def on_preset(self, text):
        print(text, flush=True)
        self.accept()

    def on_ok(self):
        query = self.input_field.text().strip()
        if query:
            print(query, flush=True)
            self.accept()
        else:
            self.input_field.setFocus()
            self.input_field.setPlaceholderText("Type your query!")


def main():
    presets = sys.argv[1:] if len(sys.argv) > 1 else ["Explain these files"]
    file_info = sys.stdin.read().strip() if not sys.stdin.isatty() else ""

    app = QApplication(sys.argv)
    app.setStyle("Breeze")

    # Default font
    font = QFont("Noto Sans", 10)
    app.setFont(font)

    dialog = AskDialog(presets, file_info)
    sys.exit(0 if dialog.exec_() == QDialog.Accepted else 1)


if __name__ == "__main__":
    main()
