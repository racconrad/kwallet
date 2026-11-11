from dataclasses import dataclass
import re

from PIL import Image


@dataclass
class Animation:
    name: str
    row: int
    frame_ms: int
    grids: list[list[str]]


def validate_palette(data):
    if not isinstance(data, dict) or not 2 <= len(data) <= 17:
        raise ValueError('Palette needs 1-16 opaque colors plus transparency')
    if '.' not in data or data['.'] is not None:
        raise ValueError('The dot must map to transparent (null)')
    palette = {'.': (0, 0, 0, 0)}
    for symbol, color in data.items():
        if symbol == '.':
            continue
        if len(symbol) != 1 or not symbol.isascii() or not symbol.isalnum():
            raise ValueError(f'Invalid palette symbol: {symbol!r}')
        if not isinstance(color, str) or not re.fullmatch(r'#[0-9a-fA-F]{6}', color):
            raise ValueError(f'{symbol}: use an opaque #RRGGBB color')
        palette[symbol] = tuple(bytes.fromhex(color[1:])) + (255,)
    return palette


def render_grid(rows, palette):
    if len(rows) != 32 or any(not isinstance(row, str) or len(row) != 32 for row in rows):
        raise ValueError('Each frame must have exactly 32 rows of 32 characters')
    unknown = set(''.join(rows)) - palette.keys()
    if unknown:
        raise ValueError(f'Undefined palette symbols: {sorted(unknown)}')
    image = Image.new('RGBA', (32, 32))
    image.putdata([palette[symbol] for row in rows for symbol in row])
    bounds = image.getbbox()
    if bounds is None:
        raise ValueError('Frame cannot be empty')
    if bounds[0] < 1 or bounds[1] < 1 or bounds[2] > 31 or bounds[3] > 31:
        raise ValueError('Keep at least one transparent pixel around the frame')
    return image
