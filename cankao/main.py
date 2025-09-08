import os, sys, json, random, ctypes, math
from PyQt5.QtWidgets import (
    QApplication, QSystemTrayIcon, QMenu, QAction, QDialog, QListWidget,
    QVBoxLayout, QHBoxLayout, QPushButton, QInputDialog, QFileDialog,
    QMessageBox
)
from PyQt5.QtGui import QIcon, QCursor
from PyQt5.QtCore import Qt
from PIL import Image, ImageDraw, ImageFont

# ===== 工具函数：获取资源路径 =====
def resource_path(relative_path):
    """获取资源文件路径，兼容开发环境和 PyInstaller 打包"""
    if hasattr(sys, "_MEIPASS"):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.abspath("."), relative_path)

# ===== 基本配置 =====
W, H = 2560, 1440
OUT = os.path.join(os.path.abspath("."), "output.jpg")
FONT_PATH = resource_path("simhei.ttf")
DEFAULT_QUOTES_PATH = resource_path("quotes.json")
ICON_PATH = resource_path("yulu.ico")

# 用户语录文件（存放在用户目录，可读写）
USER_QUOTES_PATH = os.path.join(os.path.expanduser("~"), "WallpaperApp_quotes.json")

# 主色候选
COLORS = [
    "#E57373","#F06292","#BA68C8","#9575CD","#7986CB",
    "#64B5F6","#4DB6AC","#81C784","#DCE775","#FFD54F",
    "#5488BC","#917C6B","#AA9F7C","#A29296","#515E68"
]

# ===== 语录文件操作 =====
def ensure_user_quotes():
    """确保用户语录文件存在，不存在则从默认文件复制"""
    if not os.path.exists(USER_QUOTES_PATH):
        try:
            with open(DEFAULT_QUOTES_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception:
            data = []
        with open(USER_QUOTES_PATH, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

def load_quotes():
    ensure_user_quotes()
    try:
        with open(USER_QUOTES_PATH, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []

def save_quotes(quotes):
    with open(USER_QUOTES_PATH, "w", encoding="utf-8") as f:
        json.dump(quotes, f, ensure_ascii=False, indent=2)

def pick_text():
    quotes = load_quotes()
    if quotes:
        return random.choice(quotes)
    return "为有牺牲多壮志，敢教日月换新天。"

# ===== 绘制工具函数 =====
def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def adjust_color(rgb, factor=1.0):
    r, g, b = rgb
    return (max(0, min(255, int(r*factor))),
            max(0, min(255, int(g*factor))),
            max(0, min(255, int(b*factor))))

def draw_layered_waves(draw, base_rgb):
    """画 6 层同色系正弦波：上浅下深"""
    num_layers = 6
    base_from_bottom = int(H * 0.32)
    gap_per_layer   = int(H * 0.035)
    base_wavelength = 420
    base_amplitude  = 52
    step = 6

    for i in range(num_layers):
        color = adjust_color(base_rgb, 1 - i*0.06)
        alpha = min(255, 25 + i*38)
        fill = (*color, alpha)

        wavelength = base_wavelength * (1.0 + i*0.03)
        amplitude  = base_amplitude  * (1.0 + i*0.05)
        phase      = random.uniform(0, math.tau)

        layer_offset = H - (base_from_bottom - i*gap_per_layer)

        points = []
        for x in range(0, W + step, step):
            y = layer_offset - amplitude * math.sin(2*math.pi*x / wavelength + phase)
            points.append((x, y))

        points += [(W, H), (0, H)]
        draw.polygon(points, fill=fill)

# ===== 壁纸生成 =====
def make_wallpaper():
    img = Image.new("RGBA", (W, H), "#E6E6E6")
    draw = ImageDraw.Draw(img, "RGBA")

    base_hex = random.choice(COLORS)
    base_rgb = hex_to_rgb(base_hex)
    draw_layered_waves(draw, base_rgb)

    text = pick_text()
    try:
        font = ImageFont.truetype(FONT_PATH, 80)
    except Exception:
        font = ImageFont.load_default()

    max_w = int(W * 0.8)
    lines, line = [], ""
    for ch in text:
        w = draw.textbbox((0,0), line + ch, font=font)[2]
        if w <= max_w:
            line += ch
        else:
            lines.append(line); line = ch
    if line: lines.append(line)

    line_h = draw.textbbox((0,0), "高", font=font)[3]
    total_h = len(lines) * line_h
    y = (H - total_h)//2 - int(H*0.20)
    for ln in lines:
        w = draw.textbbox((0,0), ln, font=font)[2]
        draw.text(((W - w)//2, y), ln, font=font, fill="#000000")
        y += line_h

    img = img.convert("RGB")
    img.save(OUT, quality=95)
    ctypes.windll.user32.SystemParametersInfoW(20, 0, OUT, 3)

# ===== 语录管理窗口 =====
class QuoteManagerDialog(QDialog):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("语录管理")
        self.resize(500, 400)

        self.list_widget = QListWidget()
        self.quotes = load_quotes()
        self.refresh_list()

        btn_add = QPushButton("新增")
        btn_edit = QPushButton("修改")
        btn_delete = QPushButton("删除")
        btn_import = QPushButton("导入 JSON")
        btn_export = QPushButton("导出 JSON")

        btn_add.clicked.connect(self.add_quote)
        btn_edit.clicked.connect(self.edit_quote)
        btn_delete.clicked.connect(self.delete_quote)
        btn_import.clicked.connect(self.import_quotes)
        btn_export.clicked.connect(self.export_quotes)

        layout = QVBoxLayout()
        layout.addWidget(self.list_widget)
        btns = QHBoxLayout()
        for b in [btn_add, btn_edit, btn_delete, btn_import, btn_export]:
            btns.addWidget(b)
        layout.addLayout(btns)
        self.setLayout(layout)

    def refresh_list(self):
        self.list_widget.clear()
        for q in self.quotes:
            self.list_widget.addItem(q)

    def add_quote(self):
        text, ok = QInputDialog.getText(self, "新增语录", "输入语录：")
        if ok and text:
            self.quotes.append(text)
            self.refresh_list()
            save_quotes(self.quotes)

    def edit_quote(self):
        row = self.list_widget.currentRow()
        if row >= 0:
            old = self.quotes[row]
            text, ok = QInputDialog.getText(self, "修改语录", "编辑语录：", text=old)
            if ok and text:
                self.quotes[row] = text
                self.refresh_list()
                save_quotes(self.quotes)

    def delete_quote(self):
        row = self.list_widget.currentRow()
        if row >= 0:
            del self.quotes[row]
            self.refresh_list()
            save_quotes(self.quotes)

    def import_quotes(self):
        path, _ = QFileDialog.getOpenFileName(self, "导入 JSON", "", "JSON Files (*.json)")
        if path:
            try:
                with open(path, "r", encoding="utf-8") as f:
                    self.quotes = json.load(f)
                self.refresh_list()
                save_quotes(self.quotes)
            except Exception as e:
                QMessageBox.warning(self, "错误", f"导入失败: {e}")

    def export_quotes(self):
        path, _ = QFileDialog.getSaveFileName(self, "导出 JSON", "quotes.json", "JSON Files (*.json)")
        if path:
            try:
                with open(path, "w", encoding="utf-8") as f:
                    json.dump(self.quotes, f, ensure_ascii=False, indent=2)
            except Exception as e:
                QMessageBox.warning(self, "错误", f"导出失败: {e}")

# ===== 托盘逻辑 =====
class TrayApp(QSystemTrayIcon):
    def __init__(self):
        super().__init__()
        self.setToolTip("语录壁纸")

        if not os.path.exists(ICON_PATH):
            self.setIcon(QApplication.style().standardIcon(QApplication.style().SP_ComputerIcon))
        else:
            self.setIcon(QIcon(ICON_PATH))

        self.menu = QMenu()
        next_action = QAction("下一张", self)
        manage_action = QAction("管理语录", self)
        quit_action = QAction("退出程序", self)

        next_action.triggered.connect(self.next_wallpaper)
        manage_action.triggered.connect(self.open_manager)
        quit_action.triggered.connect(self.quit_app)

        self.menu.addAction(next_action)
        self.menu.addAction(manage_action)
        self.menu.addSeparator()
        self.menu.addAction(quit_action)

        self.activated.connect(self.on_activated)

        self.dlg = None

    def next_wallpaper(self):
        make_wallpaper()

    def open_manager(self):
        if self.dlg is None:
            self.dlg = QuoteManagerDialog()
            self.dlg.setAttribute(Qt.WA_DeleteOnClose, False)
        self.dlg.show()
        self.dlg.raise_()
        self.dlg.activateWindow()

    def on_activated(self, reason):
        if reason == QSystemTrayIcon.Trigger:
            self.next_wallpaper()
        elif reason == QSystemTrayIcon.Context:
            cursor_pos = QCursor.pos()
            self.menu.exec_(cursor_pos)

    def quit_app(self):
        self.hide()
        QApplication.quit()

# ===== 程序入口 =====
if __name__ == "__main__":
    import PyQt5.QtWidgets as QW
    app = QW.QApplication(sys.argv)

    # 🚀 关键修复：关闭窗口不退出程序
    app.setQuitOnLastWindowClosed(False)

    tray = TrayApp()
    tray.show()
    tray.next_wallpaper()
    sys.exit(app.exec_())

