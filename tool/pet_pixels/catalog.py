import json
from pathlib import Path

from frame import contour, ground
from quadruped import quadruped_frame
from rooted import rooted_frame
from sprite_source import Animation, validate_palette


ACTIONS = [('idle', 240), ('curious', 180), ('happy', 180), ('stretch', 180),
           ('walk', 120), ('run', 90), ('sleep', 320), ('groom', 180),
           ('celebrate', 100), ('relax', 160)]


def load_catalog(source):
    source = Path(source)
    palette = validate_palette(json.loads((source / 'palette.json').read_text()))
    pets = {p.stem: json.loads(p.read_text()) for p in sorted((source / 'catalog').glob('*.json'))}
    for name, spec in pets.items():
        if spec['kind'] not in ('quadruped', 'plant', 'rock', 'golem'):
            raise ValueError(f'{name}: unknown pet kind')
        for part, rows in spec['parts'].items():
            if not rows or not rows[0] or any(len(row) != len(rows[0]) for row in rows):
                raise ValueError(f'{name}/{part}: inconsistent ASCII row widths')
            if set(''.join(rows)) - palette.keys():
                raise ValueError(f'{name}/{part}: undefined palette character')
    return palette, pets


def render_animations(spec):
    draw = quadruped_frame if spec['kind'] == 'quadruped' else rooted_frame
    animations = []
    for row, (name, frame_ms) in enumerate(ACTIONS):
        grids = []
        for frame in range(8):
            grid = draw(spec, row, frame)
            if row not in (5, 8):
                grid = ground(grid)
            grids.append(contour(grid))
        animations.append(Animation(name, row, frame_ms, grids))
    return animations
