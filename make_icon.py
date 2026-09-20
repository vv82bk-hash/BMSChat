# =====================================================
# 🎨 BMSChat — генератор иконки приложения
# =====================================================
# Что делает:
#   1. Берёт исходный логотип (logo.png)
#   2. Обрезает до квадрата, центрирует
#   3. Ресайзит до 1024×1024
#   4. Создаёт app_icon.png         — полная иконка с фоном
#   5. Создаёт app_icon_foreground.png — только логотип
#      с прозрачностью (для Android Adaptive Icons)
# =====================================================

from PIL import Image, ImageDraw, ImageFilter, ImageOps
import os

# ─────────────────────────────────────────────
# 📁 ПУТИ
# ─────────────────────────────────────────────
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.join(SCRIPT_DIR, "app")

SOURCE = os.path.join(APP_DIR, "assets", "images", "logo.png")
ICON_DIR = os.path.join(APP_DIR, "assets", "icon")

OUTPUT_MAIN = os.path.join(ICON_DIR, "app_icon.png")
OUTPUT_FOREGROUND = os.path.join(ICON_DIR, "app_icon_foreground.png")

SIZE = 1024  # итоговый размер иконки

# ─────────────────────────────────────────────
# 🎨 НАСТРОЙКИ
# ─────────────────────────────────────────────
# Фон для полной иконки (тёмно-чёрный, в тон логотипу)
BG_COLOR = (10, 10, 10, 255)  # #0A0A0A

# Раста-полоска (красный → жёлтый → зелёный) по нижнему краю
RASTA_STRIPE_HEIGHT = 0     # 0 = не рисовать. 60 = рисовать полоску
RASTA_RED = (230, 30, 30)
RASTA_YELLOW = (254, 209, 0)
RASTA_GREEN = (30, 180, 30)

# Насколько логотип в foreground сжимается (для adaptive icons).
# 0.66 — стандарт Android: логотип занимает центральные 66%.
# Меньше = больше пустого фона → логотип меньше при обрезке.
FOREGROUND_SCALE = 0.66


def ensure_dir(path: str) -> None:
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)


def load_source() -> Image.Image:
    """Загружает исходник и делает его квадратным."""
    if not os.path.exists(SOURCE):
        raise FileNotFoundError(f"Не найден файл: {SOURCE}")

    img = Image.open(SOURCE).convert("RGBA")
    print(f"✅ Загружен исходник: {img.size[0]}×{img.size[1]}")

    # Обрезаем до квадрата (по центру)
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    img = img.crop((left, top, left + side, top + side))

    # Ресайз до 1024×1024
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    print(f"✅ Обрезан и сжат до {SIZE}×{SIZE}")
    return img


def make_main_icon(src: Image.Image) -> None:
    """
    Полная иконка 1024×1024.
    Если у исходника есть прозрачность — заменяем её на тёмный фон.
    """
    # Создаём фон
    canvas = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)

    # Накладываем логотип поверх
    canvas.alpha_composite(src)

    # Опционально: рисуем раста-полоску снизу
    if RASTA_STRIPE_HEIGHT > 0:
        stripe = Image.new("RGBA", (SIZE, RASTA_STRIPE_HEIGHT), (0, 0, 0, 0))
        draw = ImageDraw.Draw(stripe)
        third = SIZE // 3
        draw.rectangle([0, 0, third, RASTA_STRIPE_HEIGHT], fill=RASTA_RED)
        draw.rectangle(
            [third, 0, third * 2, RASTA_STRIPE_HEIGHT],
            fill=RASTA_YELLOW,
        )
        draw.rectangle(
            [third * 2, 0, SIZE, RASTA_STRIPE_HEIGHT],
            fill=RASTA_GREEN,
        )
        canvas.alpha_composite(
            stripe,
            (0, SIZE - RASTA_STRIPE_HEIGHT),
        )

    # Финальная обрезка до непрозрачного фона
    canvas = canvas.convert("RGB")

    ensure_dir(ICON_DIR)
    canvas.save(OUTPUT_MAIN, "PNG", optimize=True)
    print(f"✅ Создана полная иконка: {OUTPUT_MAIN}")


def make_foreground(src: Image.Image) -> None:
    """
    Foreground для Android Adaptive Icons.
    1024×1024, логотип сжат в центральные FOREGROUND_SCALE,
    вокруг — прозрачный фон.
    """
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # Новый размер логотипа
    inner_size = int(SIZE * FOREGROUND_SCALE)
    inner = src.resize((inner_size, inner_size), Image.LANCZOS)

    # Центрируем
    offset = (SIZE - inner_size) // 2
    canvas.alpha_composite(inner, (offset, offset))

    ensure_dir(ICON_DIR)
    canvas.save(OUTPUT_FOREGROUND, "PNG", optimize=True)
    print(f"✅ Создан foreground: {OUTPUT_FOREGROUND}")


def main() -> None:
    print("═" * 50)
    print("🎨 BMSChat — генератор иконки")
    print("═" * 50)

    src = load_source()
    make_main_icon(src)
    make_foreground(src)

    print("═" * 50)
    print("🎉 Готово! Проверь папку:")
    print(f"   {ICON_DIR}")
    print("═" * 50)


if __name__ == "__main__":
    main()