# Hướng dẫn Gán nhãn Video cho Huấn luyện viên (Vika Evaluation)

Tài liệu này hướng dẫn cách xem video quay người tập và điền bảng nhãn vào Excel / Google Sheets, sau đó xuất ra tệp **CSV UTF-8 (`.csv`)**. File mẫu có sẵn tại `tools/eval/coach_labels_template.csv`.

---

## 1. Nguyên tắc chung

- **Mỗi dòng tương ứng với 1 lần thực hiện động tác (`rep`) hoặc 1 lần giữ Plank (`hold`)** mà HLV quan sát thấy trên video, ghi **đúng theo thứ tự thời gian**.
- Mở file `coach_labels_template.csv` bằng Excel hoặc Google Sheets, xóa các dòng ví dụ và điền dữ liệu thật (giữ nguyên dòng tiêu đề đầu tiên).
- Khi lưu file trong Excel: chọn **Save As → CSV UTF-8 (Comma delimited) (`*.csv`)** để không bị lỗi dấu tiếng Việt ở cột ghi chú.

---

## 2. Ý nghĩa từng cột

| Cột | Bắt buộc? | Cách điền | Ví dụ |
|---|---|---|---|
| `coach_id` | Có | Mã của HLV gán nhãn (giữ thống nhất một mã xuyên suốt, không thêm dấu cách). | `C1`, `C2` |
| `participant_id` | Có | Mã người tập đúng như trên tên file log/video (viết hoa thống nhất). | `P01`, `P07`, `P12` |
| `condition` | Có | Điều kiện tập: chỉ ghi **`ai`** (có giọng nói phản hồi) hoặc **`control`** (ứng dụng im lặng). | `ai` hoặc `control` |
| `exercise_id` | Có | Mã bài tập, chỉ dùng 1 trong 4 mã: `squat`, `push_up`, `glute_bridge`, `plank`. | `squat` |
| `set_index` | Có | Số thứ tự hiệp của bài tập đó trong buổi tập (bắt đầu từ `1`). | `1`, `2` |
| `rep_n` | Có | Số thứ tự lần tập/giữ do chính HLV đếm tuần tự trong hiệp (`1, 2, 3, ...`). Nếu cả hiệp người tập hoàn toàn không thực hiện lần nào, ghi 1 dòng `rep_n = 0` và `counted = 0`. | `1`, `2`, `3` |
| `video_t_s` | Khuyến khích | **Số giây tính từ tiếng "bíp" bắt đầu của ứng dụng** (nghe thấy trong video) **đến thời điểm kết thúc lần tập/giữ đó**. Ví dụ: tiếng bíp ở giây `4.2` của video, rep 1 kết thúc ở giây `16.6` → điền `12.4`. Nếu video mất tiếng bíp hoặc không xác định được, **để trống**. **Plank:** ứng dụng phát lại đúng tiếng bíp này sau mỗi lần nghỉ giữa các lần giữ, nên luôn lấy tiếng bíp **đầu tiên** của hiệp làm mốc. | `12.4` (hoặc để trống) |
| `counted` | Có | Điền **`1`** nếu HLV công nhận đây là 1 rep hợp lệ (hoặc 1 lần giữ Plank đủ ~15 giây). Điền **`0`** nếu là nhịp thử dở dang / nửa rep / gãy tư thế Plank sớm trước 15 giây. | `1` hoặc `0` |
| `faults` | Có (để trống nếu chuẩn) | Danh sách mã lỗi tư thế của lần tập đó (xem Bảng mã lỗi ở Mục 3). Nếu tập chuẩn không lỗi: **để trống**. Nếu có từ 2 lỗi trở lên trong cùng 1 rep: nối bằng dấu chấm phẩy **`;`** (không dùng dấu phẩy `,`). | `depth` hoặc `depth;tempo` |
| `note` | Tùy chọn | Ghi chú ngắn gọn bằng tiếng Việt (không ảnh hưởng đến phép tính tự động). | `thả rơi ở đáy` |

---

## 3. Bảng mã lỗi chuẩn theo từng bài tập (`faults`)

> **Quan trọng:** HLV chỉ điền đúng các mã chữ tiếng Anh ở cột **Mã lỗi (`faults`)** bên dưới để khớp 100% với từ điển lỗi của ứng dụng.

### 3.1. Bài `squat` (Squat — đếm rep)
Thời điểm kết thúc rep (`video_t_s`): khi người tập đứng thẳng trở lại vị trí ban đầu.

| Mã lỗi (`faults`) | Mô tả lỗi quan sát trên video |
|---|---|
| `depth` | **Chưa đủ sâu:** Đùi chưa hạ đủ thấp (góc gối ở đáy còn mở lớn, squat nông). |
| `trunk` | **Đổ người quá mức / ngả sau:** Thân trên gập đổ về phía trước quá nhiều (hoặc ngả ngược ra sau). |
| `tempo` | **Nhịp độ thiếu kiểm soát:** Thả rơi người xuống quá nhanh, bật nảy ở đáy không có điểm dừng ngắn, hoặc mất kiểm soát pha hạ. |
| `sync` | **Hông lên trước vai (Good-morning squat):** Khi đứng lên, mông/hông bật cao nhanh hơn vai làm lưng gập xuống. |

### 3.2. Bài `push_up` (Chống đẩy — đếm rep)
Thời điểm kết thúc rep (`video_t_s`): khi đẩy thẳng tay về lại tư thế Plank cao.

| Mã lỗi (`faults`) | Mô tả lỗi quan sát trên video |
|---|---|
| `sag` | **Lệch trục thân người (võng lưng HOẶC nhổng mông):** Hông bị chùng/võng xuống sàn **hoặc** mông đẩy nhổng cao chữ V. *(Lưu ý: phiên bản log hiện tại của ứng dụng gộp cả võng lưng và nhổng mông vào chung mã `sag`).* |
| `depth` | **Chưa đủ sâu:** Khuỷu tay gập quá ít, ngực còn quá cao nhưng vẫn đẩy lên. *(Nếu chỉ nhấp khuỷu tay rất nông không thành rep thì ghi `counted = 0`).* |
| `tempo` | **Hạ người quá nhanh:** Thả rơi tự do thân người xuống sàn thiếu kiểm soát cơ. |

### 3.3. Bài `glute_bridge` (Cầu mông — đếm rep)
Thời điểm kết thúc rep (`video_t_s`): khi hạ hông chạm về lại mặt sàn.

| Mã lỗi (`faults`) | Mô tả lỗi quan sát trên video |
|---|---|
| `hip_extension` | **Nâng hông chưa đủ cao:** Ở đỉnh động tác, hông vẫn chùng thấp dưới đường thẳng vai–gối. |
| `hyperextension` | **Ưỡn võng lưng dưới quá mức:** Đẩy bụng/lưng dưới ưỡn vồng cao vượt quá trục thẳng vai–gối. |
| `knee_angle` | **Đặt bàn chân quá gần hoặc quá xa mông:** Làm góc gập gối ở đỉnh quá nhọn hoặc duỗi quá thẳng. |
| `speed_control` | **Hạ hông rơi quá nhanh:** Không kiểm soát tốc độ lúc hạ hông từ đỉnh xuống sàn. |
| `neck_head` | **Nhấc đầu / gập cổ:** Nhấc đầu và cổ rời khỏi sàn (thường do ngóc đầu nhìn bụng/camera). |

### 3.4. Bài `plank` (Plank cẳng tay — mỗi "rep" là 1 hiệp nhỏ giữ đủ 15 giây)
- Mỗi hiệp Plank của Vika gồm các lượt giữ **15 giây** xen kẽ **5 giây nghỉ**.
- Mỗi lượt giữ hoàn thành đủ 15 giây được ghi là **1 dòng với `counted = 1`**, `video_t_s` là thời điểm kết thúc 15 giây giữ đó.
- Nếu người tập bị sập tư thế / hạ gối nghỉ sớm trước khi đủ 15 giây: ghi `counted = 0` và chú thích ở `note`.
- Gắn mã lỗi trên một lượt giữ 15 giây (`counted = 1`) khi lỗi đó kéo dài **đáng kể (khoảng gần nửa thời gian lượt giữ, > 45% tương đương ~7 giây trên 15 giây)**.
- *(Lưu ý viết hoa chữ cái đầu cho 3 mã của Plank: `Back`, `Neck`, `Knees` — kịch bản chấm vẫn tự sửa nếu lỡ gõ chữ thường, nhưng nên ghi đúng chuẩn).*

| Mã lỗi (`faults`) | Mô tả lỗi quan sát trên video |
|---|---|
| `Back` | **Võng lưng / chùng hông HOẶC nhổng cao mông:** Trục vai–hông lệch khỏi phương ngang (cả võng xuống lẫn nhổng cao đều ghi `Back`). |
| `Neck` | **Cúi gập đầu hoặc ngẩng cổ quá mức:** Đầu rủ thấp xuống sàn hoặc ngước nhìn cao làm lệch trục tai–vai–hông. |
| `Knees` | **Chùng / gập đầu gối:** Không duỗi thẳng chân, đầu gối bị chùng xuống trong lúc giữ. |

---

## 4. Kiểm tra nhanh trước khi gửi file CSV

1. Không để dòng nào trống cột `coach_id`, `participant_id`, `condition`, `exercise_id`, `set_index`, `rep_n`, `counted`.
2. Cùng một người tập không viết lúc `P07` lúc `p07` hoặc `P 07`.
3. Nhiều lỗi trong 1 lần tập phải ngăn cách bằng dấu chấm phẩy `;` (ví dụ: `depth;trunk`).
4. Nếu 2 HLV cùng chấm độc lập để đo độ đồng thuận: mỗi HLV có thể làm trên 1 file CSV riêng (ví dụ `labels_C1.csv` và `labels_C2.csv`) hoặc gộp chung vào 1 file CSV với `coach_id` khác nhau (`C1` và `C2`).
