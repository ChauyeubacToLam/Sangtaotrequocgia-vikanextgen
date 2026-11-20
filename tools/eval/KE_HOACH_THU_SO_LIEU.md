# Kế hoạch thu số liệu cho Yêu cầu 1 và 2 của giám khảo

Viết ngày 20/11/2026. Hạn nộp 23:59 ngày 26/11/2026. Đọc kèm `HUONG_DAN_GAN_NHAN.md` (cách HLV gán nhãn)
và `README.md` (cách chạy `evaluate.py`).

## 0. Mục tiêu

| Yêu cầu | Giám khảo đòi | Lấy từ đâu |
|---|---|---|
| 1. Kiểm chứng trên mẫu độc lập | Số mẫu, confusion matrix, precision/recall từng lỗi (nêu đích danh plank) | Video quay người tập thật + nhãn HLV, so với log app bằng `evaluate.py` |
| 2. An toàn khi camera không nhìn rõ | Dừng chấm, nói "chưa đủ căn cứ", nút báo sai hoặc bỏ qua cảnh báo, hướng dẫn đặt máy, ghi thời gian AI không nhìn rõ | (a) log tự động của mọi buổi quay, (b) bài thử tình huống xấu ở mục 5 |
| 3. Phản hồi AI có giá trị (đi kèm) | Có AI và không AI, lời nhắc có giúp sửa lỗi không, mức hài lòng | Cùng các buổi quay ở mục 4, không cần quay thêm |

Chỉ kiểm chứng 4 bài: `squat`, `push_up`, `glute_bridge`, `plank`.

## 1. Phải xong trước buổi quay đầu tiên

- [ ] Supabase mới chạy được (đăng ký, đăng nhập), đã tắt "Confirm email".
- [ ] APK bản release cài trên **máy A**. Bản debug chạy chậm, số FPS sẽ sai.
- [ ] Nút "Báo sai" trong lúc tập và dòng "AI nhìn rõ X%" ở màn tổng kết. **Hai thứ này chưa có trong
      code.**
- [ ] **Buổi chạy thử với 1 người trong nhóm (mã `P00`)**, đi trọn đường ống: quay, xuất log, gán nhãn
      thử 1 hiệp mỗi bài, chạy `evaluate.py` ra được `summary.md`. Bước nào hỏng thì sửa trước khi mời
      người thật. Log của `P00` không đưa vào báo cáo.
- [ ] Phiếu đồng ý quay video (người tập ký; người dưới 18 tuổi cần phụ huynh ký).
- [ ] Dụng cụ: 2 điện thoại, 2 chân máy, thảm tập, đèn, thước dây, băng dính để đánh dấu vị trí.

## 2. Bố trí chỗ quay (giữ y nguyên cho mọi người)

- **Máy A (chạy Vika):** đặt theo thẻ "Đặt máy" trong app của từng bài. Dùng **một máy duy nhất** cho
  mọi người để FPS so sánh được.
- **Máy B (quay video cho HLV):** quay nghiêng, cùng phía với máy A, cao ngang hông, thấy toàn thân,
  1080p 30 fps, **bật tiếng** để nghe tiếng bíp. **Không để màn hình máy A lọt vào khung**, để HLV không
  nhìn thấy kết quả của AI.
- Dán băng dính đánh dấu chỗ đặt hai chân máy và mép thảm. Ghi khoảng cách và chiều cao máy vào sổ.
- Ánh sáng: bật hết đèn, tránh ngược sáng (không để cửa sổ sau lưng người tập).

## 3. Người tham gia và cỡ mẫu

- **10 người** (tối thiểu 8), từ 16 tuổi, không đang đau cấp tính. Cố gắng đa dạng giới, chiều cao,
  trình độ tập.
- **Độc lập:** không dùng người đã tham gia chỉnh ngưỡng của app.
- Mã người tập: `P01` … `P10`. Mã khối lỗi cố ý: thêm chữ `S` (`P01S`). Mã bài thử an toàn: `T01`, `T02`.

Ước tính với 10 người, mỗi người 2 điều kiện × 2 hiệp mỗi bài:

| Bài | Mỗi hiệp | Tổng mẫu (lỗi tự nhiên) | Khối lỗi cố ý (mục 4.3) |
|---|---|---|---|
| squat | ~10 rep | ~400 rep | +100 rep |
| push_up | ~8 rep | ~320 rep | +80 rep |
| glute_bridge | ~10 rep | ~400 rep | +100 rep |
| plank | ~3 lượt giữ 15 s | ~120 lượt giữ | +30 lượt giữ |

Lý do có khối lỗi cố ý: người tập thật thường mắc ít lỗi, nên recall của lỗi hiếm sẽ có khoảng tin cậy
rất rộng. Báo cáo phải tách riêng "lỗi tự nhiên" và "lỗi cố ý".

## 4. Kịch bản một người (khoảng 50 phút)

### 4.1. Chuẩn bị (5 phút)
1. Ký phiếu đồng ý. Khởi động nhẹ.
2. Trên máy A: **Hồ sơ → Cài đặt nghiên cứu**. Nhập mã (`P03`), chọn điều kiện của khối 1. Kiểm tra dòng
   "Mã đang ghi vào tệp".
3. Thứ tự điều kiện **luân phiên**: mã lẻ (`P01`, `P03`…) tập **có AI trước**, mã chẵn tập **đối chứng
   trước**. Mục đích: triệt tiêu ảnh hưởng "tập lần hai thì quen hơn".
4. Bấm quay trên máy B và để quay liên tục suốt khối tập.

### 4.2. Hai khối chính (2 × 15 phút, nghỉ 5 phút giữa hai khối)
- Mỗi khối: squat, chống đẩy, cầu mông, plank. Mỗi bài 2 hiệp. Giữ đúng thứ tự này cho mọi người.
- Mỗi hiệp bắt đầu bằng tiếng bíp của app. HLV dùng tiếng bíp **đầu tiên** của hiệp làm mốc thời gian.
- Người điều phối **không nhắc lỗi** cho người tập ở cả hai điều kiện. Chỉ app được phép nhắc.
- Hết khối: người tập trả lời câu hỏi mức hài lòng trong app.
- **Trước khối 2**: vào Cài đặt nghiên cứu, đổi điều kiện. Giữ nguyên mã người tập.

### 4.3. Khối lỗi cố ý (10 phút, sau khi xong hai khối chính)
- Đổi mã thành `P03S`, điều kiện **đối chứng** (app im lặng).
- Mỗi bài 1 hiệp. Người điều phối đưa phiếu ghi sẵn thứ tự, ví dụ squat: "rep 1 đúng, rep 2 nông,
  rep 3 đúng, rep 4 nhón gót, rep 5 đổ người…". Trộn đủ các mã lỗi trong bảng mục 3 của
  `HUONG_DAN_GAN_NHAN.md`. Plank: lượt 1 đúng, lượt 2 võng lưng, lượt 3 cúi đầu.
- HLV vẫn chấm theo những gì nhìn thấy, **không chép từ phiếu**.

### 4.4. Sau mỗi người (5 phút)
1. Máy A: **Cài đặt nghiên cứu → Chia sẻ tất cả tệp nhật ký**. Lưu vào thư mục chung `logs/P03/`. App chỉ
   giữ 300 tệp mới nhất, nên phải xuất sau từng người.
2. Chép video máy B, đặt tên `P03_khoi1_ai.mp4`, `P03_khoi2_control.mp4`, `P03S_loi_co_y.mp4`.
3. Ghi sổ: giờ bắt đầu, thứ tự điều kiện, sự cố (rớt khung, máy nóng, app treo…).

## 5. Bài thử an toàn camera (Yêu cầu 2, khoảng 45 phút)

Người trong nhóm thực hiện, mã `T01`, `T02`, điều kiện **ai**. Hai bài: **squat** (máy dọc) và **plank**
(máy ngang). Bật **ghi màn hình** của Android trên máy A để có luôn cảnh quay demo cho Yêu cầu 2.

| # | Tình huống | Cách tạo |
|---|---|---|
| 1 | Ra khỏi khung một phần | Bước sang ngang cho mất cẳng chân |
| 2 | Ra hẳn khỏi khung | Đi ra khỏi tầm camera |
| 3 | Thiếu sáng | Tắt đèn chính, chỉ để đèn phụ |
| 4 | Sai chiều máy | Plank với máy dọc, squat với máy ngang |
| 5 | Sai góc nhìn | Squat quay mặt vào camera thay vì nghiêng |
| 6 | Bị che khuất | Người khác đi ngang qua, hoặc giơ khăn che |

Mỗi tình huống làm **3 lần** trong lúc đang tập. Người thử nói to "BẮT ĐẦU" khi tạo tình huống, giữ khoảng
5 giây, nói "HẾT" khi trở lại, rồi tập đúng tiếp khoảng 5 giây.

Ghi vào `an_toan_camera.csv`, một dòng một lần thử:

```csv
tester_id,exercise_id,set_index,scenario,trial,start_video_t_s,end_video_t_s,note
T01,squat,1,1,1,12.4,17.9,
```

Mỗi lần thử, đánh giá 4 thứ:
1. App có dừng chấm và hiện lời nhắc đúng loại không (có / không).
2. Độ trễ phát hiện: thời điểm `unseen_start` trong log trừ `start_video_t_s`.
3. Số rep hoặc lỗi bị ghi trong khoảng không nhìn rõ. Mong muốn bằng 0.
4. Thời gian hồi phục: từ "HẾT" đến khi app chấm lại.

Bảng này hiện phải tính bằng bảng tính. Script tính tự động **chưa có**, viết thêm nếu còn thời gian.

Ngoài bài thử này, mọi buổi quay ở mục 4 đều tự ghi thời gian AI không nhìn rõ. `evaluate.py` xuất ra
`unseen_time.csv` (tỉ lệ trên tổng thời gian tập) và `unseen_reasons.csv` (chia theo lý do).

## 6. Gán nhãn

- HLV chấm theo `HUONG_DAN_GAN_NHAN.md`, mỗi HLV một file CSV.
- **Tắt tiếng khi chấm lỗi.** Chỉ bật tiếng để tìm tiếng bíp. Ở điều kiện có AI, giọng app nói ra tên lỗi;
  nghe thấy thì HLV sẽ bị ảnh hưởng.
- HLV không xem log hay kết quả của app trước khi chấm xong.
- **Hai HLV cùng chấm ít nhất 3 người** (khoảng 30% dữ liệu) để tính độ đồng thuận (Cohen's kappa).
- Thời gian chấm ước tính gấp 2–3 lần độ dài video, khoảng 1,5–2 giờ mỗi người tập.

## 7. Chạy đánh giá

Chạy **hai lần**:

```bash
# Yêu cầu 1: dùng toàn bộ log (cả khối lỗi cố ý)
python tools/eval/evaluate.py --logs data/logs --labels data/labels --cue-map tools/eval/cue_fault_map.csv --out data/eval_all

# Yêu cầu 3: bỏ log và nhãn của các mã có đuôi S, T và P00
python tools/eval/evaluate.py --logs data/logs_natural --labels data/labels_natural --cue-map tools/eval/cue_fault_map.csv --out data/eval_natural
```

Lần 1 lấy bảng precision/recall, confusion matrix, kappa. Lần 2 lấy bảng có AI và không AI, sửa lỗi sau
lời nhắc, mức hài lòng. Bảng an toàn camera lấy từ `unseen_*.csv` của lần 2 cộng với bảng ở mục 5.

## 8. Lịch

| Ngày | Việc |
|---|---|
| 20/11 | Supabase mới, nút "Báo sai" và "AI nhìn rõ X%", build APK tối nay, buổi chạy thử `P00` |
| 21/11 | Quay 5 người (P01–P05) và bài thử an toàn `T01` |
| 22/11 | Quay 5 người (P06–P10) và bài thử `T02`. HLV bắt đầu chấm |
| 23/11 | HLV chấm xong, chấm chéo 3 người. Chạy `evaluate.py`, chọn ca nhận sai, ca sửa thành công, ca thất bại |
| 24/11 | Sửa lỗi nặng nhất, dựng video demo Yêu cầu 2 từ phần ghi màn hình |
| 25/11 | Viết báo cáo, build APK cuối |
| 26/11 | Dự phòng, nộp trước buổi tối |

## 9. Rủi ro và cách xử lý

- **Lỗi tự nhiên quá ít:** recall có khoảng tin cậy rất rộng. Đã có khối lỗi cố ý.
- **Người tập quen dần:** đã luân phiên thứ tự điều kiện. Báo cáo vẫn ghi đây là thử nghiệm sơ bộ.
- **Mất log:** xuất ngay sau từng người. Máy B quay liên tục làm bản dự phòng.
- **Máy nóng, FPS tụt:** nghỉ giữa hai người, tháo ốp. Ghi FPS (`frame_rate.csv`) vào báo cáo.
- **HLV bị ảnh hưởng bởi giọng app:** chấm khi tắt tiếng, không xem log.
