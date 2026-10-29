-- managed by MirrorOS configure
-- Default for monitors without a more specific rule.
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

-- QEMU output.
hl.monitor({
    output = "Virtual-1",
    mode = "1920x1080@60",
    position = "auto",
    scale = 1.6,
})
