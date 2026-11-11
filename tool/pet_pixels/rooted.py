from frame import blank, blink, lean, look, shifted, stamp


def rooted_frame(spec, action, frame):
    parts = spec['parts']
    closed = action == 9 or frame == 6 and action in (0, 2, 7)
    master = blink(parts['master'], spec['eyes'], spec['eye_fill']) if closed else parts['master']
    if action == 1:
        master = look(master, spec['eyes'], spec['eye_fill'], (0, 0, 1, 1, 0, -1, -1, 0)[frame])
    if action == 6:
        return lean(parts['sleep'], int(frame in (2, 3, 4, 5)))
    if spec['kind'] == 'golem':
        grid = golem_frame(spec, master, action, frame)
    else:
        amount = (0, 1, 1, 0, 0, -1, -1, 0)[frame]
        if action == 0:
            amount = 0
        if action == 9:
            amount = int(frame in (3, 4))
        if spec['kind'] == 'plant':
            grid = blank()
            top = min(y for y, row in enumerate(master) if any(c != '.' for c in row))
            extent = max(1, spec['split_y'] - top)
            for y, row in enumerate(master):
                offset = round(amount * (spec['split_y'] - y) / extent) if y < spec['split_y'] else 0
                stamp(grid, [row], offset, y)
        else:
            grid = lean(master, amount)
    if action == 5:
        grid = shifted(grid, dy=(0, -1, -2, -1, 0, -1, -2, -1)[frame])
    elif action == 8:
        grid = shifted(grid, dy=(0, 0, -1, -2, -2, -1, 0, 0)[frame])
    return grid


def golem_frame(spec, master, action, frame):
    grid = [list(row) for row in master]
    if action in (0, 9) and frame in (3, 4):
        end = spec['leaf_end']
        for y in range(end):
            grid[y] = list('.' * 32)
            stamp(grid, [master[y]], round((end - y) / 4), y)
    limbs = []
    for category in ('arms', 'feet'):
        for side, (x, y, w, h) in enumerate(spec[category]):
            part = [row[x:x + w] for row in master[y:y + h]]
            for yy in range(y, y + h):
                grid[yy][x:x + w] = ['.'] * w
            dx = dy = 0
            if action in (4, 5):
                phase = (frame + side * 4) % 8
                dx = (0, -1, -1, 0, 0, 1, 1, 0)[phase]
                dy = -1 if category == 'feet' and phase in (5, 6) else 0
            elif category == 'arms' and action in (2, 3, 7, 8):
                dy = (0, -1, -1, -2, -2, -1, -1, 0)[frame]
            limbs.append((part, x + dx, y + dy))
    for part, x, y in limbs:
        stamp(grid, part, x, y)
    return grid
