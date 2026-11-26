# Kế hoạch thu số liệu cho 3 yêu cầu của giám khảo (bản 2)

Viết lại ngày 23/11/2026, thay bản 20/11 (bản cũ còn trong commit 43aa6da). Hạn nộp 23:59 ngày 26/11/2026.
Phạm vi: **21 bài**, đúng 21 bài app đang hiện (`keptExerciseIds`). 3 bài thêm ngày 22/11 (`step_up`,
`neck_side_stretch`, `pushup_rotation`) không đưa vào nghiên cứu và đã ẩn khỏi app (quyết định 24/11): chưa đo ngưỡng trên
máy và còn thiếu giọng nói. 19 bài khác đã ẩn khỏi app. Không tuyên bố gì về 22 bài này.

Đọc kèm `HUONG_DAN_GAN_NHAN.md` (21 bài) và `README.md` (cách chạy `evaluate.py`).

## 0. Năm nguyên tắc (giám khảo bắt bẻ được ở đâu thì chặn ở đó)

1. **Độc lập.** Người tập là người mới, chưa từng góp dữ liệu chỉnh ngưỡng. Dữ liệu tự tập của nhóm (mã
   `P00`) chỉ dùng để chạy thử, hiệu chuẩn HLV và mục "trước/sau khi sửa", không bao giờ vào bảng
   precision/recall. Đề viết: "các lượt thử ban đầu chủ yếu phục vụ chỉnh ngưỡng".
2. **Mù.** HLV chấm trên clip đã cắt sẵn, **tắt tiếng**, tên file mã hoá ngẫu nhiên. HLV không biết clip
   thuộc điều kiện có AI hay đối chứng, và không thấy log hay màn hình app.
3. **Đóng băng phiên bản.** Trước người tập `P01`, chốt một bản build, ghi số build và commit hash vào báo
   cáo. Từ lúc đó đến khi thu xong **không sửa ngưỡng**. Chỉ được sửa lỗi làm app treo, và mọi lần sửa phải
   ghi lại. Sửa ngưỡng giữa chừng thì số liệu trước đó của bài đó bị loại.
4. **Đăng ký trước cách phân tích.** Chỉ số, quy tắc loại mẫu, quy tắc báo cáo và tiêu chí "Đã kiểm
   chứng" được viết ở mục 10 **trước khi** có số liệu. Kết quả xấu vẫn báo cáo.
5. **Công khai giới hạn.** Điểm mạnh giám khảo ghi nhận chính là "công khai giới hạn thử nghiệm trước khi
   mở rộng tuyên bố hiệu quả". Lỗi nào không đủ mẫu ghi "chưa đủ mẫu", không đoán.

## 1. Đối chiếu từng cụm từ trong đề với bằng chứng

### Yêu cầu 1: Kiểm chứng phản hồi tư thế trên mẫu độc lập

| Cụm từ trong đề | Cách đáp ứng | Bằng chứng nộp |
|---|---|---|
| "người hướng dẫn gán nhãn độc lập" | HLV ngoài nhóm, chấm mù (nguyên tắc 2), 2 HLV chấm chung ≥ 30% clip | File nhãn, kappa HLV–HLV |
| "người và điều kiện mới" | Người `P01`+ chưa từng tham gia; ≥ 2 địa điểm khác phòng nhóm tự tập | Bảng mẫu (cột địa điểm) |
| "nhiều vóc dáng" | Hạn ngạch ở mục 3, ghi chiều cao, cân nặng, BMI | Bảng mẫu |
| "góc máy" | Khối thay đổi điều kiện: chéo 45°, máy cao | Bảng theo điều kiện |
| "ánh sáng" | Sáng, tối, ngược sáng; đo lux bằng app đo sáng | Bảng theo điều kiện |
| "quần áo" | Bó, rộng, tối màu trùng nền; ghi quần áo thật của từng người | Bảng theo điều kiện |
| "thiết bị" | Máy A (Android của nhóm) cho mọi khối; mượn 1 máy Android khác hãng (máy D2) chỉ cho khối thay đổi điều kiện. Không mượn được thì ghi thành giới hạn | Bảng theo thiết bị, FPS |
| "precision/recall theo lỗi" | Mọi mã lỗi của cả 21 bài, kèm khoảng tin cậy 95% | `summary.md` |
| "nhất là plank" | Plank: mọi người tập, mọi khối, mọi điều kiện; cỡ mẫu lớn nhất | Mục riêng cho plank |
| "Bảng số mẫu" | Mỗi bài: số người, hiệp, rep, số rep có lỗi theo từng mã | Bảng mẫu |
| "confusion matrix theo tư thế" | 21 ma trận, mỗi bài một ma trận (ghép các mã lỗi) | `confusion_*.csv` |
| "video lỗi nhận diện" | Mỗi bài 1 clip AI bắt đúng và 1 clip AI sai (báo nhầm hoặc bỏ sót), video máy B ghép chữ "HLV: … / AI: …" | Thư mục video |

### Yêu cầu 2: Đảm bảo an toàn khi camera thiếu quan sát

| Cụm từ trong đề | Hiện trạng | Việc cần làm |
|---|---|---|
| "Hướng dẫn vị trí camera" | Có thẻ đặt máy | Đo hiệu quả: người mới tự đặt máy chỉ theo hướng dẫn trong app (mục 5, bước 2) |
| "landmark/độ tin cậy không đủ thì dừng đánh giá" | Có (`checkSafety`, `PresenceGate`) | Thử cả 21 bài vì `checkSafety` viết riêng từng bài (mục 8) |
| "cho phép bỏ qua cảnh báo" | **Đã làm 23/11.** Lời nhắc góc máy, hướng đứng, ánh sáng hiện ≥ 5 giây thì có nút "Bỏ qua cảnh báo". Bấm thì app vẫn đếm nhưng không chấm tư thế đến khi camera thấy rõ lại. Log ghi `guidance_skipped`, rep không chấm có `form_judged: false` | Thử trong bài thử an toàn (mục 8) |
| "cho phép sửa cảnh báo" | **Đã làm 23/11.** "Báo sai" trên màn nghỉ giờ còn tắt giọng nhắc lỗi đó ở các hiệp sau của bài. Log AI vẫn giữ nguyên để đo | Không làm nút lúc đang tập: người tập đứng cách máy 3 m |
| "nhắc tập an toàn" | **Đã làm 23/11.** Thẻ đặt máy của mọi bài có nhắc chung (chỗ trống, dừng nếu đau/chóng mặt/khó thở, hỏi bác sĩ). Khi AI chưa chấm hoặc đang chỉ đếm, màn tập hiện "Tập chậm và giữ an toàn" | Chỉ có chữ, chưa có giọng nói (cần thu thêm mp3) |
| Demo "mất điểm cơ thể, camera sai góc, thông báo không đủ căn cứ" | Câu "Chưa đủ căn cứ để chấm" đã có | Quay màn hình các bài thử ở mục 8 |

### Yêu cầu 3: Chứng minh giá trị của phản hồi AI

| Cụm từ trong đề | Cách đáp ứng |
|---|---|
| "so với video hướng dẫn" | Điều kiện đối chứng = xem video hướng dẫn + app đếm rep, không nhắc form (đúng cách app đang chạy ở `control`) |
| "so với đánh giá của huấn luyện viên" | So mức đồng thuận AI–HLV với HLV–HLV (cùng chỉ số kappa). AI gần bằng HLV thì AI có giá trị thay HLV khi tập một mình |
| "tập với/không phản hồi AI" | Mỗi người tập 4 bài chính ở cả hai điều kiện, thứ tự luân phiên (mục 5) |
| "so cùng nhãn chuyên gia" | Cả hai điều kiện đều được HLV chấm mù |
| "sửa đúng tư thế" | Tỉ lệ rep lỗi theo điều kiện; tỉ lệ rep kế tiếp hết lỗi sau lời nhắc, so với tỉ lệ tự sửa ở đối chứng |
| "báo nhầm" | Lời nhắc phát ra mà HLV không thấy lỗi; số lần "Báo sai" |
| "mức hài lòng" | Câu hỏi hài lòng trong app sau mỗi điều kiện + 3 câu giấy (hữu ích, tin tưởng, phiền) + "muốn tập có AI hay không" |
| "một ca thành công và một ca thất bại" | Chọn theo quy tắc viết sẵn ở mục 10.4, không chọn theo cảm tính |

## 2. Phạm vi 21 bài

- **4 bài chính** (`squat`, `push_up`, `glute_bridge`, `plank`): đủ cả 3 yêu cầu, do nhóm A (P01–P10) tập.
- **17 bài còn lại**: đủ yêu cầu 1 và 2, do nhóm B (P11–P20) tập. Yêu cầu 3 chỉ đo phía có AI (lời nhắc có làm rep sau hết lỗi
  không), so với tỉ lệ tự sửa ở đối chứng của 4 bài chính. Lý do: lời nhắc của mọi bài đi qua cùng một bộ
  máy giọng nói (`PolicyVoiceCoach`). Đo cặp đầy đủ cho 21 bài thì mỗi người phải tập 42 hiệp.
- Chia 17 bài thành 5 gói, mỗi gói 3–4 bài (trộn bài đứng, bài sàn, bài giãn cơ để đỡ mệt):

| Gói | Bài |
|---|---|
| 1 | lunge, situp, bird_dog, butterfly |
| 2 | jump_squat, leg_raises, superman, seated_forward_fold |
| 3 | jumping_jack, vup, tricep_dip |
| 4 | mcgill_curlup, mountain_climber, wall_pushup |
| 5 | dead_bug, side_plank_dip, sphinx |

Mỗi người nhóm B tập 2 gói. Mỗi gói có 4 người:

| Người | P11 | P12 | P13 | P14 | P15 | P16 | P17 | P18 | P19 | P20 |
|---|---|---|---|---|---|---|---|---|---|---|
| Gói | 1, 2 | 3, 4 | 5, 1 | 2, 3 | 4, 5 | 1, 3 | 2, 4 | 3, 5 | 4, 1 | 5, 2 |

HLV còn thời gian thì mời thêm P21–P25 (gói 1–5, mỗi người 1 gói) để mỗi gói có 5 người.

Dụng cụ thêm: ghế chắc 30–45 cm (tricep_dip), một mảng tường lọt khung máy ở 3 m (wall_pushup).

## 3. Người tham gia

- **20 người, chia 2 nhóm, mỗi người 1 buổi khoảng 50 phút.** Nhóm A (P01–P10): 4 bài chính. Nhóm B
  (P11–P20): 17 bài còn lại. Chỉ có 1 máy Android nên chỗ nghẽn là giờ máy và giờ chấm của HLV, không
  phải số người. Mỗi người tập ngắn thì đỡ mệt hơn, và có thêm người khác nhau.
- Từ 16 tuổi; dưới 18 cần phụ huynh ký.
- Hạn ngạch đa dạng, **áp cho từng nhóm**: ≥ 3 nữ, ≥ 3 nam; ≥ 2 người BMI ≥ 25 và ≥ 2 người BMI < 20;
  chiều cao chênh ≥ 20 cm giữa người thấp nhất và cao nhất; ≥ 3 người mới tập (dưới 1 buổi/tuần).
- Mời dư 3–4 người dự phòng, vì sẽ có người huỷ.
- Loại trừ (hỏi sàng lọc kiểu PAR-Q): bệnh tim, đau cấp, chấn thương đang điều trị, mang thai.
- Ghi vào `participants.csv`: mã, giới, tuổi, cao, nặng, BMI, mức tập, quần áo đang mặc, địa điểm.
- Phiếu đồng ý có **3 ô riêng**: (a) tham gia tập; (b) xử lý dữ liệu cá nhân và dữ liệu sức khoẻ theo
  Nghị định 13/2023/NĐ-CP; (c) cho dùng hình ảnh trong báo cáo. Ai không tick (c) thì video của họ chỉ
  dùng để chấm, video nộp thì làm mờ mặt.

## 4. Việc phải xong trước `P01` (hôm nay 23/11)

### 4.1. Code app
- [x] Nút "Bỏ qua cảnh báo" (ghi `guidance_skipped`, rep không chấm có `form_judged: false`). "Báo sai" tắt
      giọng nhắc lỗi đó ở các hiệp sau.
- [x] Nhắc tập an toàn trên thẻ đặt máy, và dòng "Tập chậm và giữ an toàn" khi AI chưa chấm.
- [x] `evaluate.py` bỏ các rep `form_judged: false` khỏi precision/recall và đếm riêng chúng
      (`n_unjudged_reps`); các rep này vẫn tính vào độ chính xác đếm.

### 4.2. Công cụ (xong 23/11)
- [x] **Danh mục lỗi chính thức của 21 bài**, trích từ code: `fault_catalog.csv`, 88 mã lỗi form và 2 mã trạng
      thái (`bird_dog` `MissingBody`, `Plank`), loại khỏi phép đo.
- [x] `evaluate.py` đọc 21 bài từ `fault_catalog.csv` (mặc định); `cue_fault_map.csv` đủ 21 bài.
- [x] `HUONG_DAN_GAN_NHAN.md` có đủ 21 bài, mỗi bài ghi rõ lúc kết thúc 1 lần và bài nào tính mỗi bên 1 lần.
      Cần HLV đọc lại câu chữ ở buổi hiệu chuẩn.
- [x] `clips.py`:
  - `suggest`: đánh dấu 1 tiếng bíp bằng tai là đoán được mọi hiệp khác trong cùng video, nhờ đồng hồ trong log.
  - `cut`: mỗi hiệp 1 clip, xoá tiếng, tên ngẫu nhiên; `clip_key.csv` để riêng, không nằm trong thư mục của HLV.
  - `merge`: đổi bảng HLV, vốn chỉ có `clip_id`, về đúng định dạng của `evaluate.py`.
  - **Cần cài `ffmpeg`** (`winget install Gyan.FFmpeg`) trước 24/11.
- [x] `session_conditions.csv`: `clips.py conditions` tạo sẵn khung, mỗi hiệp 1 dòng; còn phải điền góc, lux,
      quần áo, vóc dáng, địa điểm. `evaluate.py --conditions` cho ra bảng chia theo điều kiện.
- [x] Khoảng tin cậy bootstrap theo người (2000 lần), báo cáo kèm Wilson.
- [x] `clips.py overlay`: cắt đoạn ngắn quanh từng lần nhận diện sai, ghép chữ "HLV: … / AI: …".

### 4.3. Cổng chạy thử `P00` (cả 21 bài)
Nhóm tự tập mỗi bài 1 hiệp ở điều kiện `ai`, và 4 bài chính thêm 1 hiệp `control`. Mỗi hiệp tập đúng số
rep (bài giữ: số lượt) app ghi cho một hiệp, lấy từ `assets/data/exercise_catalog.json`. Ví dụ squat 8,
jumping jack 20, plank 3 lượt, plank nghiêng 1 lượt. Kịch bản từng bài: `KICH_BAN_P00.md`. Một bài **qua
cổng** khi đủ 5 điều kiện:
1. App đếm đúng số rep đó, lệch tối đa 1.
2. Log có sự kiện `rep` và mã lỗi.
3. Có tiếng bíp đồng bộ, ở cả `control`.
4. Lời nhắc lỗi phát ra tiếng (hoặc ghi rõ bài nào chỉ có chữ).
5. Xuất log được.

Riêng plank: diễn võng lưng và vểnh mông, kiểm tra app gọi **đúng tên** từng lỗi (code còn ghi "verify
sign mapping").

Điều kiện 1, 2, 3 và một phần điều kiện 4 kiểm tự động. Kéo log về, rồi chạy
`python tools/eval/p00_gate.py --logs <thư mục log P00>`. Script cũng báo bài chính nào còn thiếu hiệp `control`.
Script cũng báo mã lỗi app ghi ra mà `fault_catalog.csv` chưa có. Vẫn phải nghe bằng tai xem tiếng có phát
thật không, và xem plank gọi đúng tên lỗi.

Bài trượt cổng thì sửa ngay tối nay. Không sửa kịp thì loại khỏi đợt đo và ghi lý do trong báo cáo.

Đo FPS khi bật và tắt quay màn hình. Tụt dưới 10% thì được quay màn hình trong khối chuẩn.

Máy D2 (nếu mượn được): cài APK **cùng build**, chạy thử plank và squat, xuất log được. Xong đợt đo thì gỡ
app khỏi máy mượn.

### 4.4. Còn lại
- [ ] Hiệu chuẩn HLV 30 phút trên clip `P00`: thống nhất cách hiểu từng mã lỗi, chọn tối đa 3 lỗi diễn cố ý
      cho mỗi bài (chỉ lỗi an toàn).
- [ ] **Đóng băng build**, ghi số build và commit hash.
- [ ] Chốt lịch người tập, in phiếu đồng ý và phiếu sàng lọc.

## 5. Kịch bản một người (khoảng 50 phút)

Bố trí chuẩn: máy A nằm ngang, cao 60–70 cm, cách 3 m, nhìn nghiêng. Máy B quay nghiêng cùng phía, 1080p,
bật tiếng (để có tiếng bíp), không để màn hình máy A lọt vào khung. Máy B là điện thoại thường, chỉ quay
video, không cài Vika. Dán băng dính đánh dấu.

Hai bước mở đầu, chung cho cả 2 nhóm:
1. Ký phiếu, sàng lọc, đo chiều cao và cân nặng, đo lux phòng. Khởi động 5 phút.
2. **Thử hướng dẫn đặt máy (yêu cầu 2).** Người tập tự đặt máy A chỉ theo hướng dẫn trong app, không ai
   giúp. Ghi thời gian, khoảng cách, độ cao, góc, và app có thấy đủ người không. Sau đó người điều phối
   đặt lại máy về vạch chuẩn.

### Nhóm A: 4 bài chính (P01–P10)
3. **4 bài chính, điều kiện thứ nhất.** Mỗi bài 1 hiệp (khoảng 10 rep; plank 3 lượt giữ). Mã lẻ tập `ai`
   trước, mã chẵn tập `control` trước. Người điều phối không nhắc lỗi. Hết khối trả lời câu hỏi hài lòng.
4. Nghỉ 5 phút, đổi điều kiện. **4 bài chính, điều kiện thứ hai**, rồi trả lời câu hỏi hài lòng và 3 câu
   giấy.
5. **4 bài chính, lỗi cố ý.** Mã `P03S`, điều kiện `control`. Mỗi bài 1 hiệp theo phiếu: khoảng 1/3 rep
   đúng, còn lại chia đều các lỗi đã chọn, thứ tự xáo trộn. Plank: đúng, võng lưng, vểnh mông, cúi đầu,
   chùng gối (5 lượt).

6. **Khối thay đổi điều kiện.** Mỗi lần thay đổi gồm plank + squat, mỗi lần chỉ đổi đúng 1 yếu tố:
   - Nếu mượn được máy D2: thêm 1 lần cho mọi người, máy D2 ở vị trí chuẩn (so thiết bị trên cùng một
     người).
   - 2 lần xoay vòng để mỗi mức có ≥ 3 người:

| Mức | G2 chéo 45° | G3 máy cao 1,2 m | A2 tối 50–100 lux | A3 ngược sáng | Q2 áo quần rộng | Q3 đồ tối trên nền tối |
|---|---|---|---|---|---|---|
| Người | P01, P04, P07, P10 | P02, P05, P08 | P03, P06, P09 | P01, P05, P09 | P02, P06, P10 | P03, P04, P07, P08 |

   Chuẩn bị sẵn áo hoodie rộng, quần rộng, đồ màu tối và một tấm vải tối làm nền.

### Nhóm B: 17 bài còn lại (P11–P20)
3. **2 gói bài (8 bài).** Mỗi bài 2 hiệp: 1 hiệp tự nhiên ở `ai`, rồi 1 hiệp lỗi cố ý ở `control` (mã
   `P13S`). Thứ tự bài trong gói đảo ngược ở người kế tiếp để mệt không dồn vào một bài.

### Kết thúc (cả 2 nhóm)
- Giãn cơ. Xuất log ngay (Cài đặt nghiên cứu → Chia sẻ tất cả tệp nhật ký) vào `logs/P03/`. Chép video
   máy B. Ghi sổ sự cố.

### Số mẫu dự kiến (nhóm A 10 người, nhóm B 10 người)

| Nhóm bài | Người mỗi bài | Rep (lượt giữ) mỗi bài | Rep có lỗi mỗi mã (lỗi cố ý) |
|---|---|---|---|
| plank | 10 | ≈ 170 lượt giữ | Back ≈ 20, Neck ≈ 10, Knees ≈ 10, cộng thêm lỗi tự nhiên |
| squat | 10 | ≈ 400 | ≈ 20 mỗi mã |
| push_up, glute_bridge | 10 | ≈ 300 | ≈ 15–20 mỗi mã |
| 17 bài còn lại | 4 | ≈ 80 | ≈ 10–12 mỗi mã (với tối đa 3 lỗi diễn) |

Khoảng tin cậy 95% (Wilson) cho recall thật 0,9: với 10 rep có lỗi là 0,60–0,98; với 20 rep là
0,70–0,97; với 40 rep là 0,77–0,96. Vì vậy 17 bài phụ được ghi là "kiểm chứng sơ bộ", plank và 3 bài chính
có độ chắc cao hơn. Mã lỗi không được diễn cố ý thì phụ thuộc lỗi tự nhiên, có thể rơi vào "chưa đủ mẫu".

## 6. Quy tắc diễn lỗi cố ý
- Chỉ diễn lỗi an toàn, do HLV chọn lúc hiệu chuẩn. Không diễn lỗi gây đau hoặc dễ chấn thương. Lỗi nào
  không diễn thì ghi trong báo cáo.
- Phiếu thứ tự rep in sẵn, xáo trộn khác nhau cho mỗi người. Người tập không đeo phiếu trong khung hình.
- HLV chấm theo những gì thấy, không có phiếu. Rep diễn hụt (định diễn lỗi nhưng làm đúng) thì vẫn lấy
  nhãn HLV làm chuẩn.
- Báo cáo tách riêng kết quả trên "lỗi tự nhiên" và "lỗi cố ý".

## 7. Thiết bị và metadata
- Máy A: máy Android duy nhất của nhóm, dùng cho mọi buổi (ghi model, Android version, build). Máy chạy
  khoảng 10 giờ mỗi ngày nên dễ nóng: tháo ốp, cắm sạc giữa các người, đặt quạt, nghỉ 5 phút giữa hai
  người. FPS của từng hiệp có trong log; hiệp nào FPS tụt mạnh thì ghi sổ.
- Máy D2: mượn 1 máy Android khác hãng, tốt nhất là máy cấu hình thấp hơn (ghi model). Chỉ dùng trong khối
  thay đổi điều kiện của nhóm A, khoảng 5 phút mỗi người. iOS chưa đo đợt này.
- Máy B: bất kỳ điện thoại nào quay được 1080p, không cài Vika.
- ≥ 2 địa điểm khác nhau, không dùng phòng nhóm đã tự tập để chỉnh ngưỡng.
- Mỗi hiệp một dòng trong `session_conditions.csv`. Lux đo bằng app đo sáng đặt ở chỗ người tập.

## 8. Bài thử an toàn camera (yêu cầu 2)

Người trong nhóm làm (mã `T01`), điều kiện `ai`, quay màn hình máy A suốt buổi. Yêu cầu 2 đo hành vi
của app, không cần người độc lập.

| # | Tình huống | 4 bài chính | 17 bài còn lại |
|---|---|---|---|
| 1 | Mất một phần cơ thể (bước ngang mất cẳng chân) | 3 lần | 2 lần |
| 2 | Ra hẳn khỏi khung | 3 lần | — |
| 3 | Thiếu sáng | 3 lần | — |
| 4 | Xoay máy sang dọc | 3 lần | — |
| 5 | Sai góc (quay mặt vào máy) | 3 lần | 2 lần |
| 6 | Bị che khuất | 3 lần | — |
| 7 | Đứng sai hướng hoặc tối ≥ 5 giây, bấm "Bỏ qua cảnh báo" | 1 lần | — |
| 8 | Bấm "Báo sai" một lỗi, kiểm tra hiệp sau không nhắc lỗi đó | 1 lần | — |

Tổng khoảng 160 lần thử, khoảng 3 giờ. Mỗi lần thử đo 4 thứ:
1. App có dừng chấm và đưa đúng lời nhắc không.
2. Độ trễ phát hiện.
3. Số rep hoặc lỗi bị ghi trong lúc không nhìn rõ (phải bằng 0).
4. Thời gian hồi phục.

Ghi vào `an_toan_camera.csv`, chạy `camera_safety.py`.

Ngoài bài thử này, có thêm số liệu ngoài đời thật từ buổi tập của P01–P10:
- tỉ lệ thời gian AI không nhìn rõ, theo bài và theo điều kiện;
- số rep bị chấm trong lúc không nhìn rõ;
- kết quả thử tự đặt máy ở bước 2.

Video demo nộp: cắt từ phần quay màn hình. Gồm mất điểm cơ thể, sai góc, câu "Chưa đủ căn cứ để chấm",
nút bỏ qua, và lời nhắc an toàn.

## 9. Gán nhãn
- Một người trong nhóm (không phải HLV) ghi mốc tiếng bíp vào `beep_times.csv`, rồi chạy script cắt clip
  tắt tiếng, đặt tên ngẫu nhiên.
- **2 HLV.** HLV1 chấm toàn bộ. HLV2 chấm ≥ 30% clip, chọn ngẫu nhiên, có đủ plank. Chỉ có 1 HLV thì HLV
  đó chấm lại 20% clip sau ít nhất 12 giờ (độ đồng thuận với chính mình), và ghi rõ hạn chế này.
- Khối lượng chấm: khoảng 18 phút video có tập mỗi người, chấm mất khoảng 45 phút. 20 người là khoảng 15
  giờ, cộng chấm chéo là khoảng 20 giờ công, tức khoảng 10 giờ mỗi HLV từ tối 24/11 đến trưa 26/11.
- Thứ tự chấm: plank trước, rồi 3 bài chính, rồi 17 bài còn lại. Nếu hết giờ thì phần thiếu là bài phụ,
  không phải plank.
- HLV chấm xong mới được xem kết quả của app.

## 10. Cách phân tích (đăng ký trước)

### 10.1. Yêu cầu 1
- Precision, recall, F1 cho từng mã lỗi của 21 bài; confusion matrix mỗi bài; khoảng tin cậy Wilson và
  bootstrap theo người.
- **Quy tắc báo cáo:** mã lỗi có < 10 rep HLV gán lỗi thì ghi "chưa đủ mẫu (n = …)", không báo con số.
- Đếm rep: sai số so với HLV, tỉ lệ hiệp đếm lệch không quá ±1.
- Chia theo điều kiện (góc, sáng, quần áo, thiết bị) và theo vóc dáng (BMI). Ở điều kiện xấu, app có hai
  cách phản ứng đúng: chấm đúng, hoặc từ chối chấm. Cách sai là **chấm sai mà không báo thiếu căn cứ**.
  Báo cả 3 tỉ lệ.
- Đồng thuận: kappa HLV–HLV và AI–HLV.

### 10.2. Yêu cầu 2
- 4 chỉ số ở mục 8, theo tình huống và theo bài.
- Tỉ lệ thời gian không nhìn rõ ngoài đời thật.
- Tỉ lệ tự đặt máy đúng ngay lần đầu.

### 10.3. Yêu cầu 3
- Tỉ lệ rep lỗi (theo nhãn HLV) ở `ai` và `control`, so cặp theo từng người (Wilcoxon, 10 người nhóm A), báo hiệu
  số và khoảng tin cậy bootstrap.
- Tỉ lệ rep sau hết lỗi khi có lời nhắc, so với tỉ lệ tự sửa ở `control`.
- Báo nhầm: lời nhắc không khớp nhãn HLV, trên mỗi hiệp; số lần "Báo sai" và "Bỏ qua cảnh báo".
- Hài lòng: điểm trung bình theo điều kiện; số người muốn tập có AI.
- Hiệu ứng thứ tự: so nhóm tập `ai` trước với nhóm tập `control` trước. Người tập học từ AI rồi mang sang
  đối chứng thì chênh lệch bị **thu nhỏ**, nghĩa là kết quả thiên về thận trọng. Ghi rõ điều này.

### 10.4. Chọn ca thành công và ca thất bại (quy tắc viết trước)
- **Thành công:** hiệp có AI, có rep lỗi được HLV xác nhận, lời nhắc phát ra, rep kế tiếp HLV chấm hết lỗi
  đó. Nếu có nhiều ca, chọn ca của plank trước.
- **Thất bại:** ưu tiên ca AI chấm sai mà không báo thiếu căn cứ. Nếu không có, lấy ca báo nhầm làm người
  tập đổi tư thế sai đi. Kèm phân tích nguyên nhân và cách sửa.

### 10.5. Từ số liệu ra quyết định sản phẩm
- Một bài được gắn nhãn **"Đã kiểm chứng"** trong app khi đủ cả hai điều kiện:
  1. Mọi mã lỗi đủ mẫu có precision ≥ 0,80 và recall ≥ 0,70.
  2. ≥ 90% hiệp đếm lệch không quá ±1 rep.
- Bài không đạt giữ nhãn "Chỉ đếm, chưa kiểm chứng".
- Mã lỗi có precision < 0,60 thì **tắt lời nhắc giọng nói** của lỗi đó ở bản phát hành, để tránh hướng dẫn
  sai. Đây là kết quả cải tiến nói được với giám khảo.

## 11. Lịch

| Ngày | Việc |
|---|---|
| 23/11 | (Xong: nút bỏ qua, báo sai tắt nhắc, lời nhắc an toàn.) Danh mục lỗi, mở rộng `evaluate.py`, hướng dẫn gán nhãn, script cắt clip. Cổng `P00` cho 21 bài. Hiệu chuẩn HLV. Đóng băng build. Chốt người tập |
| 24/11 | 8:00–19:00: nhóm A, P01–P10, mỗi người 1 khung 1 giờ (55 phút tập + 5 phút nghỉ máy). Từng người xong thì cắt clip luôn; HLV chấm từ chiều |
| 25/11 | 8:00–19:00: nhóm B, P11–P20. Tối: thử an toàn `T01` (khoảng 3 giờ, cùng máy A). HLV chấm tiếp, chấm chéo |
| 26/11 | Sáng: HLV chấm xong, chạy đánh giá cuối, chọn ca, dựng video. Chiều: điền báo cáo, xuất Word. Nộp trước 20:00 |

Chỉ có 1 máy Android nên cả lịch xếp nối tiếp trên máy đó. Mỗi khung 1 giờ có sẵn 1 người dự phòng; ai
huỷ thì người dự phòng vào thay, giữ nguyên mã và gói của người huỷ.

## 12. Thiếu nguồn lực thì cắt gì

Người không thiếu. Thứ có thể thiếu là giờ máy, giờ HLV, hoặc máy A hỏng. Cắt theo thứ tự này:
1. Bài thử an toàn trên 17 bài phụ, giảm còn 1 lần mỗi tình huống.
2. Mức Q3, rồi mức G3.
3. Nhóm B giảm còn 3 người mỗi gói (bỏ P19, P20; P16–P18 đổi gói để mỗi gói vẫn có ≥ 3 người).
4. HLV2 chấm chéo giảm từ 30% xuống 20%, vẫn đủ plank.

Máy A hỏng hoặc treo kéo dài: mượn một Android khác, cài cùng build, chạy lại cổng `P00` cho 4 bài chính
trên máy đó, ghi rõ từ người nào đổi máy.

**Không bao giờ cắt:** plank ở mọi khối, chấm mù, đóng băng build, 2 điều kiện của 4 bài chính, quy tắc
"chưa đủ mẫu".

## 13. Giới hạn sẽ ghi sẵn trong báo cáo
- 20 người, một thành phố, là thử nghiệm sơ bộ; 4 bài chính có 10 người, 17 bài phụ có 4 người mỗi bài.
- Lỗi cố ý dễ nhìn hơn lỗi tự nhiên, nên recall trên lỗi cố ý có thể cao hơn thực tế. Hai nhóm được báo
  riêng.
- Yêu cầu 3 đo cặp trên 4 bài; 17 bài còn lại chỉ đo phía có AI.
- Thiết bị: 1 máy Android cho mọi buổi, thêm 1 máy Android mượn cho khối thay đổi điều kiện (nếu mượn
  được). Chưa đo trên iOS, dù app có bản iOS.
- Ngưỡng được chỉnh trên dữ liệu của nhóm phát triển (`P00`); số liệu kiểm chứng chỉ lấy từ người mới.
