from frame import blank, blink, shifted, stamp


def quadruped_frame(spec, action, frame):
    parts, anchors = spec['parts'], spec['anchors']
    grid = blank()
    walking = action in (3, 4, 5)
    sleeping = action == 6
    closed = sleeping or action == 9 or frame == 6 and action in (0, 2, 7)
    if action == 2 and frame in (2, 3, 4, 5):
        closed = True
    head = blink(parts['head'], spec['eyes'], spec['eye_fill']) if closed else parts['head']
    head_x, head_y = anchors['sleep_head' if sleeping else 'walk_head' if walking else 'head']
    if sleeping:
        x, y = anchors['sleep']
        stamp(grid, parts['sleep_tail'], x - 4, 26)
        stamp(grid, parts['sleep'], x, y - (frame in (2, 3, 4, 5)))
    elif walking:
        bob = (0, 0, -1, -1, 0, 0, -1, -1)[frame] if action == 4 else 0
        x, y = anchors['walk']
        stamp(grid, parts['walk_tail'], *anchors['walk_tail'])
        phase = 0 if action == 3 else (0, 1, 2, 1, 3, 1, 2, 1)[frame]
        stamp(grid, parts[f'feet_{phase}'], *anchors['feet'])
        stamp(grid, parts['walk'], x, y + bob)
        head_y += bob + ((0, 1, 2, 3, 3, 2, 1, 0)[frame] if action == 3 else 0)
    else:
        tx, ty = anchors['tail']
        tail = parts['tail']
        sway = (0, 0, -1, -1, 0, 1, 1, 0)[frame]
        for y, row in enumerate(tail):
            stamp(grid, [row], tx + (sway if y < len(tail) - 3 else 0), ty + y)
        stamp(grid, parts['sit'], *anchors['sit'])
        if action == 1:
            head_x += (0, 0, 1, 1, 0, -1, -1, 0)[frame]
        elif action in (7, 9):
            head_y += (0, 0, 1, 1, 1, 0, 0, 0)[frame]
    stamp(grid, head, head_x, head_y)
    if action == 7:
        paw_y = head_y + len(head) + (0, -1, -2, -3, -3, -2, -1, 0)[frame]
        stamp(grid, parts['paw'], head_x + 1, paw_y)
    if action == 5:
        grid = shifted(grid, dy=(0, -1, -2, -1, 0, -1, -2, -1)[frame])
    if action == 8:
        grid = shifted(grid, dy=(0, 0, -1, -2, -2, -1, 0, 0)[frame])
    return grid


