# Ảnh "Tư thế mẫu" cho 21 bài đang mở

Ảnh dùng cho khung bóng người trên camera và màn "Tư thế mẫu" (`lib/screens/exercise/setup/`).
Thiếu ảnh thì app vẫn chạy: khung góc và đường sàn vẫn hiện, màn Tư thế mẫu chỉ hiện chữ.

## Quy cách chung

- Lưu đúng tên `assets/pose_guide/<catalogId>.png` (bảng dưới), PNG **nền trong suốt**.
- Bài đứng: 1024×1536 (dọc). Bài nằm, ngồi: 1536×1024 (ngang).
- Có đủ ảnh rồi mới thêm dòng `    - assets/pose_guide/` vào mục `assets:` của `pubspec.yaml`
  và chạy `fvm flutter pub get`. Khai báo thư mục chưa có ảnh sẽ làm build lỗi.
- Không cần đánh dấu khớp: app tự dò khớp bằng ML Kit ngay trên máy lúc mở màn Tư thế mẫu.

Đoạn prompt chung (dán trước mỗi prompt riêng):

```
Photorealistic studio photo of the same fit Vietnamese woman in her mid-20s for every image:
black hair in a high ponytail, plain white sports bra, black high-waist leggings.
Full body completely inside the frame with about 6% empty margin on every side, nothing cropped.
Camera at hip height, perfectly level. Soft even studio light, no harsh shadows.
Transparent background (PNG with alpha). No floor, no shadow, no mat, no props, no text,
no logo, no watermark. Anatomically correct hands and feet. Neutral calm expression.
```

## Prompt riêng từng bài

| catalogId | Khổ | Prompt riêng |
|---|---|---|
| `squat` | 1024×1536 | Exact 90° side view, she faces the right edge. Standing tall, feet hip-width apart, knees straight, both feet flat, arms relaxed at her sides. White running shoes. |
| `push_up` | 1536×1024 | Exact side view, head toward the right edge. High plank: arms straight, hands directly under shoulders, body one straight line from head to heels, on her toes. Barefoot. |
| `glute_bridge` | 1536×1024 | Exact side view, head toward the right edge. Lying on her back, head and shoulders on the floor, knees bent about 90°, feet flat near the buttocks, arms along the body palms down. Barefoot. |
| `plank` | 1536×1024 | Exact side view, head toward the right edge. Forearm plank: forearms on the floor, elbows directly under shoulders, body straight from shoulders to heels, on her toes, knees straight. Barefoot. |
| `lunge` | 1024×1536 | Exact side view, she faces the right edge. Standing tall, hands on hips, feet under the hips, looking forward. White running shoes. |
| `jump_squat` | 1024×1536 | Exact side view, she faces the right edge. Standing tall, feet shoulder-width, knees soft (not locked), both feet flat, arms relaxed at her sides. White running shoes. |
| `jumping_jack` | 1024×1536 | Front view, she faces the camera. Standing tall, arms straight down at her sides, feet together. White running shoes. |
| `wall_pushup` | 1024×1536 | Exact side view, she faces the right edge. Body leaning slightly forward in one straight line from head to heels, arms straight forward at shoulder height with palms pressed flat against an invisible vertical surface (do not draw a wall), feet about one arm's length behind the hands. White running shoes. |
| `situp` | 1536×1024 | Exact side view, head toward the right edge. Lying on her back, back flat on the floor, knees bent about 90°, feet flat, hands crossed on the chest. Barefoot. |
| `leg_raises` | 1536×1024 | Exact side view, head toward the right edge. Lying on her back, lower back pressed to the floor, both legs straight and together resting on the floor, arms along the body palms down. Barefoot. |
| `vup` | 1536×1024 | Exact side view, head toward the right edge. Lying flat on her back, both arms extended straight overhead on the floor, legs straight and together. Barefoot. |
| `mcgill_curlup` | 1536×1024 | Exact side view, head toward the right edge. Lying on her back, both hands palms-down under the lower back, the leg nearer the camera bent with the foot flat on the floor, the other leg straight on the floor. Barefoot. |
| `dead_bug` | 1536×1024 | Exact side view, head toward the right edge. Lying on her back, lower back pressed to the floor, both arms straight up toward the ceiling, hips and knees bent 90° with shins parallel to the floor. Barefoot. |
| `bird_dog` | 1536×1024 | Exact side view, head toward the right edge. On hands and knees: wrists directly under shoulders, knees directly under hips, flat back, neck in line with the spine, eyes to the floor. Barefoot. |
| `mountain_climber` | 1536×1024 | Exact side view, head toward the right edge. High plank: arms straight, hands under shoulders, body straight from head to heels, on her toes. Barefoot. |
| `superman` | 1536×1024 | Exact side view, head toward the right edge. Lying face down, forehead just above the floor, arms extended straight forward on the floor, legs straight, tops of the feet on the floor. Barefoot. |
| `tricep_dip` | 1536×1024 | Exact side view, she faces the right edge. Sitting on the floor, hands flat on the floor behind the hips with fingers pointing toward the hips, arms straight, knees bent, feet flat, hips lifted slightly off the floor. Barefoot. |
| `side_plank_dip` | 1536×1024 | Front view, her chest faces the camera. Side plank on one forearm: elbow directly under the shoulder, hips lifted, body one straight line from head to feet, legs straight and stacked, head toward the right edge, free hand on the hip. Barefoot. |
| `seated_forward_fold` | 1536×1024 | Exact side view, she faces the right edge. Sitting tall on the floor, both legs straight forward and together, hands resting on the thighs, spine upright. Barefoot. |
| `butterfly` | 1536×1024 | Front view, she faces the camera. Sitting tall on the floor, soles of the feet pressed together, heels pulled toward the hips, knees relaxed outward and down, hands holding the feet. Barefoot. |
| `sphinx` | 1536×1024 | Exact side view, head toward the right edge. Lying face down propped on both forearms, elbows directly under the shoulders, chest lifted, hips and legs relaxed on the floor. Barefoot. |

## Kiểm tra ảnh trước khi đưa vào app

- Nền trong suốt thật (không phải ô caro vẽ giả); mở bằng trình xem ảnh có nền tối để kiểm tra.
- Toàn thân nằm trọn khung, đúng hướng ghi trong bảng, đúng một người.
- Cùng một người mẫu, cùng trang phục ở cả 21 ảnh.
