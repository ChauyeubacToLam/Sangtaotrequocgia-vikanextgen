# Nhật ký test thực tế 24 bài

Một file cho cả việc test, kết quả và các lần sửa, để sau làm báo cáo. Mỗi lần phân tích log hay sửa
code thì ghi thêm vào mục 4 và 5.

## 1. Cách test

- App trên máy: bản `com.vikavn.app.dev`, cài lúc 03:04 ngày 21/11. Bản này đã có camera mở nhanh,
  đã bỏ lỗi gót chân của squat, có nút "Xuất tệp nhật ký" ở màn nghỉ.
- Đặt máy giống màn "Đặt máy": điện thoại nằm ngang, cao 60–70 cm, cách khoảng 3 m, thấy cả người.
  Ánh sáng chiếu vào người, không đứng ngược nắng.
- Mỗi bài:
  1. Đứng vào tư thế bắt đầu, giữ yên 3 giây cho app kích hoạt.
  2. Rep 1: làm đúng form.
  3. Rep 2: cố tình mắc lỗi ghi ở từng bài bên dưới.
  4. Bấm quay lại, chọn "Thoát". Set dở vẫn được ghi log (app ghi khi set có khung hình), không cần
     tập hết set.
- Bài giữ (plank, side plank dip, sphinx, ngồi gập người, cánh bướm): rep 1 giữ đúng, rep 2 giữ và
  làm lỗi vài giây.
- Ghi tay ngay sau mỗi bài (vào ô "ghi chú"): camera mở sau mấy giây, app đếm được mấy rep, rep 1 có
  bị báo lỗi oan không, rep 2 có bắt được lỗi cố ý không, giọng nói nói gì.
- Về nhà: cắm máy vào máy tính, chạy `tools/eval/pull_phone_logs.ps1`. Log về
  `tools/eval/phone_logs/`.

## 2. Checklist

Đã test thật trước đó: chỉ có Squat (3 set ngày 20/11). 20 bài còn lại chưa test trên máy.

### Đứng

- [x] **Squat**. Rep 2: xuống nông, đùi chưa ngang (`depth`), hoặc đổ người ra trước (`trunk`).
  Test lại sau khi bỏ lỗi gót. Ghi chú: test lại 21/11, hết lỗi gót; lỗi tempo đã sửa (5.12), cần
  test lại.
- [x] **Lunge**. Rep 2: đổ người ra trước (`trunk`). Ghi chú: test 21/11, đã sửa (5.4), cần test lại.
- [x] **Jump Squat**. Rep 2: tiếp đất gối thẳng, cứng (`landing_stiff`), hoặc nhún nông rồi bật
  (`takeoff_depth`). Ghi chú: test 21/11, đã sửa (5.5), cần test lại và đứng lùi ~3,5 m.
- [x] **Jumping Jack**. Rep 2: tay không đưa qua đầu (`arms`), hoặc chân mở hẹp (`legs`). Ghi chú:
  test 21/11, đếm được; bị chặn "quay mặt vào camera" nhiều (mục 6).
- [x] **Wall Push-up** (cần tường). Rep 2: gập hông hoặc võng người (`body_line`), hoặc đưa đầu ra
  trước (`head`). Ghi chú: test 21/11, đã sửa (5.6), cần test lại.
- [ ] **Step-up** (bài mới 22/11, cần ghế chắc cao 40–45 cm, đặt ghế trước mặt, người nghiêng với
  máy). Rep 1 bước chân gần camera, rep 2 bước chân xa camera: cả 2 phải được đếm. Rep 3 cố ý sai:
  đặt chân lên ghế rồi bước xuống mà không đứng thẳng trên ghế (không được tính, log `noCount: height`),
  hoặc đứng trên ghế mà đổ người ra trước (`trunk`). Ghi chú:
- [ ] **Giãn cổ nghiêng** (bài mới 22/11, quay mặt vào máy, giữ 20 s mỗi bên). Lần 1 nghiêng tai trái về
  vai, giữ đúng. Lần 2 cố ý sai: nghiêng bên phải nhưng nhún vai lên vài giây (`shrug`), hoặc nghiêng
  cả vai theo đầu (`shoulder`); đồng hồ phải dừng lúc đó. Thử thêm: nghiêng nhẹ (dưới khoảng 25°) thì
  đồng hồ không chạy; nghiêng lại đúng bên vừa giữ thì app nhắc đổi bên. Ghi chú:

### Chống tay, plank

- [x] **Push-up**. Rep 2: xuống nông (`depth`) hoặc võng hông (`sag`). Ghi chú: test 21/11, người
  test chưa tập đúng được nên tạm để đó, chưa kết luận.
- [x] **Plank** (giữ 15 s). Rep 2: giữ đúng vài giây rồi võng hông (`trunk_seconds`). Ghi chú: test
  21/11, đã sửa (5.8), cần test lại.
- [x] **Side Plank Dip**. Rep 2: hạ hông rất ít (`amplitude`), hoặc vai không nằm thẳng trên khuỷu
  (`shoulder`). Ghi chú: test 22/11 (`175416Z`, `175551Z`), giữ 20 s × 2 lần, không báo lỗi nào.
- [x] **Mountain Climber**. Rep 2: kéo gối thấp (`rom`), hoặc nhổng/võng hông (`trunk`). Ghi chú:
  test 21/11, rep đá chân thẳng vẫn được đếm nhưng bị ghi lỗi `rom`, không có giọng nhắc (mục 6).
- [x] **Tricep Dip** (trên sàn). Rep 2: không duỗi hết tay (`extension`), hoặc đẩy hông lên
  (`hip_thrust`). Ghi chú: test 21/11, 0 rep; đã đổi cách đếm (5.11), cần test lại.
- [ ] **Chống đẩy xoay người** (bài mới 22/11, người nghiêng với máy). Rep 1: chống đẩy xuống, đẩy lên,
  xoay mở tay gần camera lên trần, hạ về. Rep 2: mở tay xa camera. Cả 2 phải được đếm. Rep 3 cố ý sai:
  chống đẩy xong chỉ nhấc tay nửa chừng, không xoay hẳn, rồi chống đẩy tiếp (không được tính, log
  `noCount: rotation`), hoặc võng hông khi chống đẩy (`body_line`). Ghi chú:

### Nằm ngửa

- [x] **Glute Bridge**. Rep 2: nâng hông thấp (`hip_extension`), hoặc ưỡn quá (`hyperextension`).
  Ghi chú: test 21/11, ưỡn quá bắt đúng 2/2 rep cố tình sai; lỗi đầu báo sai, đã sửa (5.10), cần test lại.
- [ ] **Sit-up**. Rep 2: lên không hết (`rom`), hoặc giật người lên (`jerking`). Ghi chú: log
  `124024Z` chỉ mở camera 4,9 s, chưa vào bài (0 rep, thời gian tập 0 s).
- [ ] **Leg Raises**. Rep 2: co gối (`knee`), hoặc thả chân xuống nhanh (`tempo`). Ghi chú:
- [ ] **V-up**. Rep 2: co gối (`knee`), hoặc tay và chân không lên cùng lúc (`sync`). Ghi chú:
- [ ] **McGill Curl-up**. Rep 2: lấy tay kéo cổ (`neck_pull`), hoặc nâng vai quá cao
  (`trunk_high`). Ghi chú:
- [ ] **Dead Bug**. Rep 2: duỗi tay chân cùng bên (`opposite_side`), hoặc ưỡn lưng khỏi sàn
  (`anti_extension`). Ghi chú:

### Quỳ bốn điểm, nằm sấp

- [x] **Bird Dog**. Rep 2: tay chân cùng bên (`opposite_side`), hoặc ưỡn lưng (`lumbar`). Ghi chú: test
  21/11, đã sửa (5.7), cần test lại.
- [ ] **Superman**. Rep 2: hông nhấc khỏi sàn (`hip`), hoặc tay chân nâng thấp (`elevation`).
  Ghi chú:
- [ ] **Sphinx**. Rep 2: chống thẳng tay thay vì cẳng tay (`straight_arm_seconds`), hoặc nhún vai
  (`shrug_neck_seconds`). Ghi chú:

### Ngồi

- [ ] **Seated Forward Fold**. Rep 2: co gối (`knee_bent_seconds`), hoặc gù lưng, gục đầu
  (`spine_round_seconds`). Ghi chú:
- [ ] **Butterfly**. Rep 2: một gối cao một gối thấp (`knee_seconds`), hoặc gù lưng
  (`posture_seconds`). Catalog ghi bài này chưa chấm form. Ghi chú:

## 3. Câu hỏi cần trả lời cho từng bài

1. Đếm rep: đúng 2/2 không, có đếm thừa hay sót không.
2. Rep đúng (rep 1): có bị báo lỗi oan không.
3. Rep sai (rep 2): có bắt được đúng lỗi cố ý không.
4. Hướng dẫn trước khi tập: có kẹt ở "quay ngang", "vào khung", "thiếu sáng" không.
5. Camera: mở sau bao lâu.

## 4. Kết quả

Số liệu lấy thẳng từ log set (`tools/eval/phone_logs/`). "Thời gian tập" là `active_ms` (từ lúc kích hoạt
đến hết set), "bị chặn" là phần thời gian tập app không chấm vì hướng dẫn khung hình (`unseen`).

| Bài | Log | Rep đếm / đúng form | Thời gian tập | Bị chặn | Lỗi báo (số rep) | Vấn đề tìm ra | Đã sửa |
|---|---|---|---|---|---|---|---|
| Squat | 20/11, 3 set | 17 rep | — | — | gót: báo khi đang đứng; tempo: 17/17 rep, thời gian xuống ≈0,2 s | Gót: đo sai do góc máy. Tempo: nghi ngưỡng sai | Gót: 5.1. Tempo: chưa |
| Lunge | `205017Z` | 10 / 0 | 48,3 s | 5,1 s (20 lần "thiếu sáng", 1 lần quay ngang) | gót 10/10; "quá sâu" 3/10 (góc gối trước 43°, 43°, 52°) | Gót: đo sai như squat. "Quá sâu" sai ngưỡng, giọng nói ngược nghĩa | 5.4 |
| Jump Squat | `205256Z` | 2 / 1 | 47,4 s | 8,8 s (16 lần quay ngang = 4,7 s; 6 lần mất khung xương = 4,1 s) | lấy đà nông + tiếp đất cứng: 1 rep | Đầu ra khỏi khung khi bật; đọc nhầm hướng đứng khi nhảy | 5.5 |
| Wall Push-up | `205618Z` | 10 / 3 | 36,7 s | 0 s | tay rời tường 7/10 (rep 4–10); tempo 2; đầu 1 | Mốc tay lấy 1 lần lúc bắt đầu; từ rep 4 tay lệch mốc sẵn nên rep nào cũng báo | 5.6 |
| Bird Dog | `205730Z` | 5 / 3 | 78,6 s | 14,7 s (12,8 s mất khung ở cuối) | duỗi chưa thẳng 8 lần (2 rep đếm + 6 lượt không đếm), phần lớn bật 0,1–0,6 s trước khi kết thúc lượt | Rep 1–5 đếm (giữ 2,2–3,0 s), sau đó ≥5 lượt trong 30 s không đếm. Chốt bên tay/chân ở khung lúc đang hạ xuống; lỗi "duỗi chưa thẳng" bắt cả lúc hạ | 5.7 |
| Squat (lần 2) | `034924Z` (21/11) | 8 / 3 | 43,2 s (chuẩn bị 33,9 s trước đó) | 0 s | gót 0/8; độ sâu 0/8; tempo 5/8 (xuống 0,09; 0,21; 0,25; 0,25; 0,26 s) | Hết lỗi gót. Tempo chỉ đo một đoạn của pha xuống (gối 121–144° tới 105–111°, trong khi đáy thật 76–84°) nên ra quá ngắn | Gót: 5.1 (đã xác nhận). Tempo: 5.12 |
| Squat (lần 3) | `174710Z` (22/11, bản có sửa tempo) | 8 / 5 | 27,8 s | 0,9 s (mất khung, rất ngắn) | tempo 0/8 (xuống 0,69–1,08 s, lên 0,64–0,81 s); độ sâu 0/8 (gối 65–75°); hông–vai `sync` 3/8: rep 2 "nhiều" (tỉ lệ > 1,0), rep 6 và 8 "hơi" (0,85–1,0); màn hình hiện "Cố giữ ngực mở" ở đáy cả 8 rep (thân đổ 35–39°, ngưỡng nhắc 30°) | Tempo đã đúng sau 5.12. `sync` ngưỡng 0,85 bắt cả lúc hông và vai lên cùng tốc độ (tỉ lệ ≈ 1), nghi báo sai; lỗi này không có giọng nói | Tempo: 5.12 (đã xác nhận). `sync`: 5.13 |
| Buổi tập đủ 4 bài, Squat set 1 | `175551Z` (22/11) | 9 / 2 | 34,9 s | 1,3 s | `sync` 6/9 (5 "hơi", 1 "nhiều"); rep 9 bất thường (xuống 0,12 s, lên 7,8 s, báo độ sâu dù gối 55°) | Gối sâu 51–55°. `sync` vẫn là vấn đề ngưỡng; giọng "squat.sync" có phát ở lần đầu | `sync`: 5.13. Rep 9: chưa |
| Squat set 2 | `175551Z` (22/11) | 11 / 0 | 107,8 s | 30,1 s = 28% (mất khung 24 lần = 23,9 s; quay ngang 14 lần = 6,2 s) | `sync` 8; thân 6; tempo 5 | Rep 4–7 có góc thân đúng 0,0 (app chỉ đo góc thân khi đứng nghiêng hẳn, nghi người đứng chéo camera nên không kiểm thân); rep 9 gối 10,6° và thân 90°, rep 11 gối 20,7°, là số không thể có thật, nhưng rep vẫn được đếm | Chưa |
| Wall Push-up (2 set) | `175551Z` (22/11) | 21 / 21 | 21,0 + 15,3 s | 0 s | tay rời tường 0/21; tempo 5 (không tính lỗi form) | Bản sửa 5.6 đúng trên máy (trước: 7/10 rep báo tay rời tường). Set 2 rep 3 khuỷu chỉ xuống 129° vẫn tính đúng form. Thời gian lên đo được 0,03–0,09 s (dải đếm hẹp, mục 6). Set 2: rep 3 + 4 và rep 8 + 9 là 1 lần chống đẩy bị đếm thành 2 | 5.6 (đã xác nhận). Đếm đôi: 5.15 |
| Side Plank Dip (2 set) | `175551Z` (22/11) | 2 lần giữ 20 s / 2 | 20,5 + 22,5 s | 0,6 + 2,4 s | không lỗi | Góc thân 177–180° | — |
| Glute Bridge (2 set) | `175551Z` (22/11) | 22 / 22 | 14,0 + 6,7 s | 0 s | đầu/cổ 0/22; tốc độ hạ 22/22, góc gối 19/22 (đều không tính lỗi form) | Bản sửa 5.10 đúng trên máy: tai lúc nằm cao hơn vai 0,14–0,16 chiều dài thân (đúng độ lệch cũ gây báo sai), mức nâng đầu đo được chỉ 0,01–0,04. 22 rep trong khoảng 17 s (0,4–0,75 s mỗi rep); nhiều rep được đếm khi hông chỉ hạ khoảng nửa đường rồi nâng lại, chưa về sàn | 5.10 (đã xác nhận). Đếm nửa rep: 5.14 |
| Glute Bridge | `035210Z` (21/11) | 7 / 0 | 60,0 s | 5,6 s (cuối set, đứng dậy) | đầu/cổ 7/7 rep + 1 lượt bỏ dở; ưỡn quá 2/7 (rep 6–7, cố tình, độ lệch hông +0,08 và +0,077); góc gối 5/7 (72–78°, không tính lỗi form); tốc độ hạ 7/7 (không tính lỗi form) | Lỗi đầu bật đúng ~0,45–0,5 s (= 10 khung chống nhiễu) sau khi bắt đầu nâng hông ở cả 8 lượt, tức đúng ngay từ khung đầu: lệch cố định chứ không phải ngẩng đầu | 5.10 |
| Push-up | `040552Z` (21/11) | 2 / 0 | 23,7 s | 4,1 s (cuối set) | võng hông 2/2 (lệch thân 21,5–22,6°); tempo 2/2 (xuống 0,25 và 0,13 s); khuỷu thấp nhất 109–110° | Người test chưa tập đúng được bài này, tạm để đó | — |
| Tricep Dip | `040628Z` (21/11) | 0 / 0 | 18,4 s | 5,0 s (cuối set: quay ngang 3,4 s, mất khung 1,6 s) | — | Vào bài lúc 7,9 s rồi đứng yên ở pha bắt đầu 13,3 s, không đổi pha lần nào. Bài đếm theo "nhấc mông cao hơn lúc bắt đầu", trong khi người tập gập/duỗi khuỷu | 5.11 |
| Jumping Jack | `040702Z` (21/11) | 6 / 6 | 43,8 s | 10,7 s = 24% ("quay mặt vào camera" 29 lần = 5,2 s; mất khung 6 lần = 3,7 s; thiếu sáng 11 lần = 1,8 s) | — | Lúc mở: tay 174–180°, chân mở 1,28–1,66 lần vai. Có 12,5 s (26,8–39,3 s) không đổi pha | Chưa |
| Mountain Climber | `040755Z` (21/11) | 10 / 7 | 19,1 s | 5,9 s (hầu hết sau rep 10) | `rom` 3/10 (rep 3–5, gối ở đỉnh 124–142°, các rep khác 59–100°); võng hông 1 | Rep đá chân thẳng vẫn được đếm, có ghi lỗi `rom` nhưng giọng nói chỉ đếm số, không nhắc | Chưa |
| Plank | `210225Z` | 0 lần giữ / 15 s | 36,8 s | 5,7 s | "Chống bằng cẳng tay" 8 lần, cách nhau 2,5–6,3 s; "Thẳng đầu gối" 1 | Mạch giữ bị đứt liên tục, dài nhất ≈6,3 s; câu nhắc không nói đúng lý do | 5.8 |

## 5. Các lần sửa

### 5.1 Squat: bỏ lỗi "gót chân nhấc" (20–21/11)

- Hiện tượng: đứng thẳng, gót chạm sàn mà app vẫn báo nhấc gót.
- Nguyên nhân: metric so độ cao ảnh của gót với mũi chân (`foot.y - heel.y`), chia theo khoảng vai–hông,
  ngưỡng 0,18. Ở 3 m, gót nhấc thật 1 cm chỉ khoảng 3 px, nhưng log cho thấy chênh lệch đo được là
  50–120 px tùy góc máy. Tức là phần lớn con số là do góc đặt máy, không phải do gót.
- Sửa: xóa `lib/exercise/squat/metrics/heel_rise_metric.dart`, bỏ metric khỏi `squat.dart` (giữ khóa
  `heel_fails_count = 0` cho tương thích), xóa 2 chú thích "Gót chân" trên màn tập, sửa test
  (`squat_form_test.dart` có test "gót nhấc không bao giờ báo lỗi"), bỏ dòng `heel` của squat trong
  hướng dẫn gán nhãn `tools/eval/HUONG_DAN_GAN_NHAN.md`.
- Còn lại: Lunge có metric gót giống hệt (`lunge_heel_lift_metric.dart`), chờ test.

### 5.2 Camera mở chậm (21/11)

- Hiện tượng: chờ lâu trước khi camera hiện, set nào cũng vậy.
- Nguyên nhân (đo bằng logcat): bộ nhận dáng MediaPipe chạy GPU mất khoảng 5 giây để khởi tạo (5,4 s
  set 1, 5,0 s set 2). Việc này chạy trên luồng chính trước khi mở camera, và bị làm lại mỗi set vì hết
  set app xóa nó. Lần chờ khoảng 12 giây ở set 2 là do lỡ giữ nút nguồn (Bixby bật), không phải lỗi code.
- Sửa:
  - `PoseLandmarkerPlugin.kt`: tạo bộ nhận dáng ở luồng nền, camera mở ngay không chờ; giữ nó suốt buổi,
    chỉ xóa khi đóng app; thêm lệnh `warmUp`.
  - `PoseLandmarkerHelper.kt`: thêm `releasePendingFrames()` để dọn khung hình chờ khi tắt camera.
  - `exercise_experience_screen.dart`: gọi `warmUp` khi mở màn giới thiệu bài (chỉ Android).
- Kiểm tra: analyze sạch, 59 test màn hình qua, bản debug 03:04 ngày 21/11 build được. Chưa đo lại
  thời gian trên máy: đo trong buổi test này.

### 5.3 Lấy log nhanh (20–21/11)

- Nút "Xuất tệp nhật ký" ở màn nghỉ, xuất log ngay sau một set (`rest_screen.dart`,
  `exercise_experience_screen.dart`, `research_session_tracker.dart`).
- Log Android chuyển sang thư mục ngoài của app để adb đọc được; log cũ tự chuyển sang khi mở app
  (`research_log_storage.dart`).
- Script `tools/eval/pull_phone_logs.ps1` kéo log về máy tính, có chế độ theo dõi liên tục
  (`-Watch`). Đọc được cả bản app chính và bản `.dev`.

### 5.4 Lunge: bỏ lỗi gót và lỗi "quá sâu" (21/11)

- Hiện tượng (log `vika_20261120T205017Z`, 10 rep): lỗi gót báo cả 10/10 rep trong khi gót chạm sàn.
  3 rep gối sau chạm sàn bị báo lỗi độ sâu, và giọng nói bảo "hạ gối sau xuống gần sàn hơn".
- Nguyên nhân gót: metric lunge đo giống hệt metric gót squat đã bỏ (`foot.y - heel.y` chia khoảng
  vai–hông), ngưỡng còn thấp hơn (0,10). Khi bàn chân phẳng, điểm gót của MediaPipe vẫn nằm cao hơn
  điểm mũi chân trong ảnh, nên con số luôn vượt ngưỡng.
- Nguyên nhân độ sâu: lỗi `depth` của lunge thực chất là "quá sâu" (góc gối trước < 55°). Ba rep đó có
  góc gối trước 43°, 43°, 52° vì gối sau chạm sàn, tức là xuống đủ sâu, không phải sai. Còn file giọng
  nói `lunge/depth.mp3` được thu cho nghĩa ngược lại ("xuống thấp hơn"), nên người tập nghe app bảo
  xuống thêm trong khi gối đã chạm sàn.
- Sửa:
  - Xóa `lib/exercise/lunge/metrics/lunge_heel_lift_metric.dart`, bỏ khỏi `lunge.dart` và giọng nói;
    khóa `heel_lift_fails_count` vẫn ghi 0 cho báo cáo cũ đọc được.
  - `lunge_depth_metric.dart`: bỏ lỗi "quá sâu"; góc gối trước ≤ 125° đều là "Độ sâu tốt". Rep nông
    vẫn bị loại như cũ (không tính rep).
  - `LungeRepContext` bỏ trường `heelDistance`; màn tập bỏ chú thích "Gót chân", chú thích độ sâu đổi
    thành "≤ 125°".
  - Test mới trong `lunge_form_test.dart`: gối gập tới 30° vẫn "Độ sâu tốt" và không lỗi; một rep
    không có lỗi `depth` hay `heel`, hai khóa set-log vẫn có.
- Kiểm tra: analyze sạch (chỉ còn 1 thông báo cũ), toàn bộ test 750 qua, 14 bỏ qua. Chưa thử lại trên
  máy.

### 5.5 Jump Squat: mất khung khi bật nhảy (21/11)

- Hiện tượng (log `vika_20261120T205256Z`): chỉ đếm 2 rep trong 47 giây tập. Người tập thấy đầu ra
  khỏi khung khi bật lên.
- Nguyên nhân:
  - Trong 47,4 s tập, app chặn khung hình 16 lần (tổng 4,7 s, mỗi lần 0,09–1,25 s) với lý do "hãy
    quay ngang", dù người tập vẫn đứng nghiêng. Cách đoán hướng đứng dựa vào tỉ lệ bề rộng vai / chiều
    dài thân; khi nhảy, tỉ lệ này nhảy qua vùng "nghiêng chéo" vài khung là app dừng chấm.
  - 6 lần mất hẳn khung xương (tổng 4,1 s, lần cuối 3,6 s), trùng lúc đầu ra khỏi khung hình. Máy đặt
    cao 60–70 cm, cách 3 m thì phía trên đầu không còn chỗ cho cú bật.
  - Lần bay chỉ khoảng 0,3–0,5 s; mất mấy khung đó là máy trạng thái không thấy pha "bay", nên lần nhảy
    bị coi là bỏ dở, không tính rep.
- Sửa:
  - `jump_squat.dart`: khi đang tập, nếu khung hình đọc ra "nghiêng chéo" hoặc thiếu điểm thì giữ hướng
    nghiêng đã biết; chỉ khi người tập quay hẳn mặt về máy mới nhắc quay ngang.
  - `camera_placement_card.dart`: Jump Squat dùng chung hướng dẫn đặt máy của Jumping Jack ("lùi
    ~3,5 m, chừa chỗ trên đầu"); hằng số đổi tên thành `kJumpPlacementWhere`.
  - Test mới trong `jump_squat_form_test.dart`.
- Chưa làm: nếu lùi xa mà vẫn mất khung xương lúc bay, bước tiếp theo là cho phép tính rep khi mất
  dấu ngắn giữa pha bật và pha tiếp đất.
- Kiểm tra: như 5.4. Chưa thử lại trên máy.

### 5.6 Wall Push-up: báo "chống tay vào tường" dù tay đang chạm tường (21/11)

- Hiện tượng (log `vika_20261120T205618Z`, 10 rep, 3 rep đúng form): lỗi `hand` ("Tay bị di chuyển",
  giọng nói "Chống tay vào tường") ở 7/10 rep, liền từ rep 4 đến rep 10. Rep 1–3 không bị.
- Nguyên nhân: metric so vị trí cổ tay (tính theo bàn chân) với một mốc duy nhất lấy lúc giữ yên bắt đầu
  bài, ngưỡng lệch 14% chiều dài thân, cần 8 khung liên tiếp. Tính ngược từ log: ở cả 7 rep, lỗi bật
  đúng khoảng 0,33 s (8 khung) sau khi rep bắt đầu xuống, tức là tay đã lệch mốc ngay từ đầu rep, không
  phải trượt trong rep. Sau rep 3 người tập đặt lại tay (hoặc nhích chân) một chút là mọi rep sau đều bị
  báo, và câu giọng nói làm người tập hiểu là tay không chạm tường.
- Sửa: `metrics/wall_contact.dart` lấy mốc ở khung đầu tiên của mỗi rep, nên chỉ báo khi tay trượt trong
  lúc đang chống đẩy. Bỏ mốc lúc bắt đầu bài trong `wall_push_up.dart`. Thêm `handAnchorDriftMax` (độ
  lệch lớn nhất của rep) vào số liệu chẩn đoán.
- Test: `wall_push_up_form_test.dart` (đặt lại tay giữa 2 rep thì không lỗi; trượt 20% trong rep thì
  lỗi), sửa `wall_push_up_anti_cheat_test.dart` cho tay trượt trong rep.
- Chưa sửa, ghi lại: 7/10 rep có góc khuỷu nhỏ nhất chỉ 116–130° (gần như không gập) vẫn được đếm, góc
  khuỷu lớn nhất chỉ 138–153° (tay chưa bao giờ đo ra thẳng), thời gian đẩy lên trung bình 0,04 s. Máy
  trạng thái đếm rep chỉ cần khuỷu đi qua dải 132–138°, quá hẹp. Cần số liệu từng pha (5.9) trước khi
  chỉnh.

### 5.7 Bird Dog: đổi bên đúng mà không tính rep, cứ nhắc "vươn dài tay chân" (21/11)

- Hiện tượng (log `vika_20261120T205730Z`): 5 rep đầu được đếm (giữ 2,2–3,0 s), sau đó 30 s (59–89 s)
  có ít nhất 5 lượt lên tới pha giữ nhưng 0 rep. Lỗi "Tay/Chân duỗi chưa thẳng" bật 8 lần, phần lớn
  0,1–0,6 s trước khi lượt kết thúc. Log cũ không ghi lý do không tính rep.
- Nguyên nhân 1 (không tính rep), tái hiện được bằng test: app xác định tay nào, chân nào đang duỗi
  (để kiểm tra "tay chân đối nhau" và "đổi bên") bằng cách so góc hai tay, hai chân, và chốt kết quả ở
  khung cuối cùng của pha giữ. Khung cuối đó là lúc tay chân đang hạ xuống, hai bên gập gần bằng nhau,
  nên kết quả gần như ngẫu nhiên. Test với rep đúng (chân trái + tay phải, giữ 2,5 s): code cũ báo
  "Không cùng tay cùng chân" và không tính; code mới tính 1 rep.
- Nguyên nhân 2 ("vươn dài tay chân"): lỗi duỗi chưa thẳng (tay hoặc chân lệch quá 35° so với mặt đất)
  xét ở mọi khung của pha giữ, kể cả lúc đang hạ tay xuống.
- Sửa:
  - `bird_dog.dart`: chỉ chốt bên tay khi tay còn duỗi (> 135°), bên chân khi chân còn duỗi (> 145°).
  - `metrics/alignment_metric.dart`: xét lỗi duỗi chưa thẳng và cúi đầu theo khung tốt nhất của cả pha
    giữ, chấm một lần khi rời pha giữ.
  - Test mới trong `bird_dog_form_test.dart`: hạ tay cuối pha giữ không bị lỗi và rep được tính; giữ
    tay chếch 36° suốt pha giữ thì vẫn bị lỗi.
- Chưa chắc 100% đây là lý do của cả 5 lượt bị loại trên máy (log cũ không ghi lý do). Bản mới ghi lý
  do vào log (5.9).

### 5.8 Plank: mạch giữ đứt liên tục, nhắc "Chống bằng cẳng tay" (21/11)

- Hiện tượng (log `vika_20261120T210225Z`): 36,8 s tập, 0 lần giữ đủ 15 s. Câu "Chống bằng cẳng tay"
  phát 8 lần, cách nhau 2,5–6,3 s, nên mạch giữ dài nhất khoảng 6,3 s.
- Nguyên nhân: câu này phát khi mạch giữ đứt vì một trong hai lý do: khuỷu tay > 125°, hoặc app cho là
  "đang đứng" (hông cách mũi chân theo chiều dọc ảnh > 0,5 chiều dài thân). Ở plank cẳng tay thật,
  thân dốc từ vai xuống chân nên hông cao hơn mũi chân khá nhiều. Với tư thế mẫu trong test (thân thẳng,
  dốc từ vai xuống chân), tỉ lệ này là 0,82, vượt ngưỡng, nên app coi là đứng dù người đang plank. Điều kiện "đang đứng" cũng thừa: đứng thì thân dựng đứng, đã bị điều kiện "thân gần nằm ngang
  (≤ 35°)" loại rồi.
- Sửa: `plank.dart` bỏ điều kiện "đang đứng" khỏi tư thế bắt đầu và tư thế giữ, bỏ câu nhắc tương ứng.
- Test mới trong `plank_form_test.dart`: plank cẳng tay dốc (hông cao hơn mũi chân 0,82 thân) vẫn vào
  được pha giữ (code cũ không vào được).
- Chưa loại trừ: nếu khuỷu đo ra > 125° thì mạch vẫn đứt. Bản mới ghi góc khuỷu và từng điều kiện vào
  log mỗi khi đứt mạch (5.9).

### 5.9 Log ghi từng pha tập (21/11)

- Lý do: log cũ chỉ có rep được đếm, lỗi và giọng nói. Lượt không được tính không để lại dấu vết, nên
  không biết vì sao Bird Dog, Plank, Jump Squat bỏ sót.
- Sửa: `set_recorder.dart` ghi sự kiện `phase` mỗi khi bài đổi pha (ví dụ `standing → descending`), kèm
  số liệu chẩn đoán của khung đó (góc khớp, cờ điều kiện, độ lệch...) và thông báo trên màn hình (gồm lý
  do "Không tính rep"). Tài liệu: `docs/reference/session-log-schema.md`. Script phân tích cũ bỏ qua loại
  sự kiện mới nên không ảnh hưởng.
- Test: `plank_form_test.dart` kiểm tra log có pha `setup → holding` kèm góc khuỷu 90°.
- Kiểm tra cho 5.6–5.9: analyze sạch (chỉ còn 1 thông báo cũ), toàn bộ test 756 qua, 14 bỏ qua. Chưa
  thử lại trên máy.

### 5.10 Glute Bridge: cứ nhắc "giữ đầu trên sàn / giữ đầu thẳng" dù đầu nằm yên (21/11)

- Hiện tượng (log `vika_20261121T035210Z`): lỗi `neck_head` ở cả 7/7 rep và 1 lượt nâng bỏ dở, nên
  0/7 rep đúng form dù chỉ rep 6–7 cố tình sai. Giọng nói phát 7 lần: "Bạn giữ đầu trên sàn, mắt nhìn
  lên trần nhé" (5 lần) và "Lần này bạn nhớ giữ đầu thẳng nhé" (2 lần).
- Cách đo cũ: so độ cao tai với độ cao vai trên ảnh. Tai cao hơn vai quá 0,14 chiều dài vai–hông,
  liên tục 10 khung, thì báo lỗi. Nếu tai không rõ thì dùng mũi. Không xét lúc đang nằm ở đáy.
- Nguyên nhân: ở cả 8 lượt, lỗi bật 415–502 ms sau khi bắt đầu nâng hông. Ở 19 khung/s, 10 khung là
  khoảng 470 ms, nghĩa là điều kiện "đầu nâng" đúng ngay từ khung đầu tiên của pha nâng, khi hông mới
  lên được khoảng 27 px. Đầu đã "cao hơn vai" sẵn từ lúc nằm, nên đây là độ lệch cố định giữa điểm tai
  (hoặc mũi) và điểm vai khi nằm ngửa nhìn ngang, không phải người tập ngẩng đầu. Khi nằm ngửa, mũi luôn
  chĩa lên trần nên dùng mũi thay tai càng lệch. Log cũ không ghi độ cao đầu nên không biết lệch bao
  nhiêu.
- Sửa:
  - `metrics/glute_bridge_neck_head.dart`: lấy mốc là vị trí đầu thấp nhất trong lúc nằm nghỉ ở đáy (cập
    nhật mỗi lần về đáy). Khi nâng hông chỉ báo lỗi nếu đầu cao hơn mốc đó quá 0,14 chiều dài vai–hông,
    liên tục 10 khung. Dùng "thấp nhất" thay vì trung bình để vài khung ngẩng đầu ngay lúc bắt đầu nâng
    không kéo mốc lên.
  - `glute_bridge.dart`: chỉ dùng tai phía camera, không dùng mũi. Mỗi rep ghi thêm `head_lift_rest`
    (độ cao tai so với vai lúc nằm, đơn vị chiều dài vai–hông) và `peak_head_lift` (đầu nâng cao nhất
    so với mốc trong rep), để lần test sau có số đo thật.
- Giới hạn: nếu người tập ngẩng đầu suốt cả set, kể cả lúc nằm nghỉ, thì không bị bắt.
- Test mới trong `glute_bridge_neck_head_test.dart`: tai nằm sẵn cao hơn vai 0,30 suốt rep thì không báo
  (code cũ báo); đầu nằm sàn rồi nâng lên 0,30 khi nâng hông thì báo; ngẩng đầu ngay lúc hông vừa nhấc
  vẫn báo.
- Kiểm tra: 26 test liên quan qua, analyze sạch. Chưa thử lại trên máy.
- Các lỗi khác của bài này trong log, không đổi: góc gối lúc nâng 72–78° ở rep 1–5 (dưới 85°, nhắc
  "dời chân xa hông", không tính lỗi form); tốc độ hạ ở 7/7 rep (nâng khoảng 0,9 s, hạ khoảng 0,5 s,
  quy định hạ phải chậm hơn nâng 1,3 lần). Hai lỗi này không có giọng nói trong log.

### 5.11 Tricep Dip: tập mà không được tính rep nào (21/11)

- Hiện tượng (log `vika_20261121T040628Z`): vào bài lúc 7,9 s, sau đó 13,3 s đứng yên ở pha bắt đầu
  (`setup_top`), không có sự kiện `phase` nào khác, 0 rep.
- Cách đếm cũ: lúc vào bài app ghi độ cao hông. Rep chỉ được tính khi hông cao hơn mức đó ít nhất 0,22
  chiều dài vai–hông (khoảng 10–11 cm), và phải hạ mông về gần mức cũ (≤ 0,07) mới đếm rep tiếp. Góc
  khuỷu không hề được đo.
- Nguyên nhân: cách đếm này không khớp với bài dip, và cũng không khớp câu hướng dẫn của chính app ("Hạ
  người xuống rồi đẩy thẳng tay lên nhé"). Điều kiện vào bài cho phép hông cao tới 0,65 thân, nên nếu
  vào bài khi đã chống tay nâng hông (tư thế đầu của dip), mức gốc đã là hông cao. Gập tay hạ người thì
  hông thấp hơn gốc, đẩy lên thì về lại gốc, không bao giờ vượt +0,16 để bắt đầu pha nâng. Khớp với log:
  không đổi pha lần nào. Bàn tay và bàn chân đứng yên khi dip nên điều kiện "tay chân chống sàn" (lệch
  0,43, ngưỡng 0,55) không phải lý do. Log cũ không ghi độ cao hông từng khung nên chưa đo được hông đã
  lên xuống bao nhiêu.
- Sửa:
  - `tricep_dip.dart`: đếm theo góc khuỷu (vai–khuỷu–cổ tay, phía gần camera). Khuỷu < 150° bắt đầu
    xuống; ≤ 120° là đã xuống đủ; ≥ 130° bắt đầu đẩy lên; ≥ 150° (tay gần thẳng) thì tính 1 rep. Mỗi
    bước cần 2 khung liền. Mông có chạm sàn hay không đều được. Chỉ đẩy hông mà không gập tay thì không
    tính. Vẫn giữ điều kiện tay chân chống sàn.
  - Mỗi rep ghi `min_elbow_angle` và `top_elbow_angle`; khung nào cũng ghi `elbowAngle` nên sự kiện
    `phase` có góc khuỷu.
  - `exercise_definition.dart`: sửa mô tả, phụ đề và mẹo thứ 3 cho đúng cách đếm mới.
- Test viết lại trong `tricep_dip_floor_setup_test.dart`: gập xuống 90° rồi duỗi là 1 rep; dip với hông
  lơ lửng đếm 2 rep liền, không cần ngồi xuống; nâng hông mà không gập tay thì 0 rep (code cũ đếm); gập
  tới 128° rồi duỗi thì 0 rep. Trong `batch_b_review_probe_test.dart`: probe cũ (nâng hông 0,15 m, tay gần
  thẳng) giờ kỳ vọng 0 rep; probe mới dip hình học thật (khuỷu 163° xuống 103° trong 1 s rồi lên) đếm 1
  rep, ghi `min_elbow_angle` ≈ 103°, cho cả hai bên trái/phải.
- Kiểm tra: analyze sạch, toàn bộ test 762 qua, 14 bỏ qua. Chưa thử lại trên máy.
- Ngưỡng 120°/150° là ước lượng cho dip trên sàn (tay thẳng khoảng 170°, đáy khoảng 90–100°), chưa đo
  trên máy.

### 5.12 Squat: báo "xuống quá nhanh" ở rep xuống bình thường (21/11)

- Hiện tượng: lần 1 (20/11) lỗi tempo ở 17/17 rep, thời gian xuống đo được khoảng 0,2 s. Lần 2 (log
  `vika_20261121T034924Z`) lỗi ở 5/8 rep, thời gian xuống 0,09; 0,21; 0,25; 0,25; 0,26 s (ngưỡng tốt
  0,30 s, dưới 0,20 s là lỗi nặng). Giọng nói nhắc "Chậm lại" sau 5 rep đó.
- Cách đo cũ: thời gian xuống tính từ lúc app vào pha "xuống" tới lúc vào pha "đáy". Pha "xuống" chỉ
  bắt đầu khi gối đã gập hơn lúc đứng 28° và app đã thấy gối đang gập liên tục vài khung; pha "đáy" bắt
  đầu khi gối ≤ 115°.
- Nguyên nhân, đo từ sự kiện `phase` của log lần 2: app vào pha "xuống" khi gối đã ở 121–144° và vào
  "đáy" ở 105–111°, trong khi gối sâu nhất của các rep là 76–84°. Gối đứng thẳng khoảng 174°. Vậy chỉ
  khoảng 15–40° trong tổng khoảng 90–100° của pha xuống được tính giờ, nên thời gian luôn quá ngắn. Test
  mô phỏng một rep xuống đều trong 0,8 s (174° tới 80°, 20 khung/s): code cũ đo ra 0,30 s.
- Sửa:
  - `metrics/tempo_metric.dart`: mốc bắt đầu là khung cuối cùng gối còn ở tư thế đứng (trong vòng 10°
    so với góc đứng lúc bắt đầu bài). Mốc kết thúc là lúc gối tới gần điểm sâu nhất (trong vòng 5°),
    theo dõi ngay từ lúc rời tư thế đứng, không phụ thuộc lúc nào app vào pha "xuống". Thời gian xuống
    được tính khi bắt đầu đứng lên. Ngưỡng 0,30 / 0,20 s giữ nguyên.
  - `squat.dart`: gửi góc gối từng khung cho metric tempo, kèm cờ "đang ở tư thế đứng".
- Test mới trong `squat_form_test.dart`: xuống đều 0,8 s đo ra 0,70 s (10° đầu không tính) và không báo
  lỗi (code cũ đo 0,30 s); rơi xuống trong 0,25 s vẫn báo lỗi tempo.
- Kiểm tra: analyze sạch, toàn bộ test 764 qua, 14 bỏ qua. Thử trên máy 22/11 (log `174710Z`): 8 rep,
  0 lỗi tempo, thời gian xuống 0,69–1,08 s (trung bình 0,86 s), lên 0,64–0,81 s.
- Giữ nguyên: thời gian giữ ở đáy vẫn tính từ lúc gối ≤ 115° tới lúc bắt đầu đứng lên, nên gồm cả
  đoạn xuống dưới 115°. Cách này dễ dãi hơn thực tế, chưa thấy báo sai trong log.

### 5.13 Squat: lỗi hông–vai (`sync`) bắt nhầm rep đúng (22/11)

- Hiện tượng: lỗi `sync` ở 3/8 rep (log `174710Z`), 6/9 rep (`175551Z` set 1) và 8/11 rep (`175551Z`
  set 2). Lỗi được tính là sai form nên các rep này không được tính "đúng form".
- Nguyên nhân: metric cũ so tốc độ đi lên của hông với tốc độ đi lên của vai (đo trên 3 khung). Tỉ lệ
  > 0,85 trong 3 khung là lỗi "hơi", > 1,0 là lỗi "nhiều". Khi thân giữ nguyên góc nghiêng lúc đứng lên,
  hông và vai đi lên đúng cùng tốc độ, tỉ lệ = 1,0, vượt ngưỡng 0,85. Nghĩa là động tác đúng ("hông và
  ngực lên cùng lúc") bị báo lỗi, chỉ rep nào thân dựng lên nhanh hơn hông mới thoát. Tốc độ tính trên 3
  khung nên rất nhiễu.
- Sửa (`metrics/hip_shoulder_sync.dart`): đo thẳng hệ quả của lỗi. Hông lên trước vai thì thân đổ thêm
  về trước, nên metric lấy góc thân ở khung cuối trước khi đứng lên làm mốc rồi theo dõi góc thân trong
  pha đứng lên. Thân đổ thêm > 10° trong 3 khung liền là lỗi (vẫn tính sai form); 6–10° chỉ là mức "gần
  lỗi", không ghi lỗi. Góc thân chỉ đo khi đứng nghiêng hẳn với camera; khung đứng chéo không có góc thân
  nên bỏ qua và lấy lại mốc ở khung nghiêng kế tiếp (tránh nhảy giả từ 0° lên 33°).
- Thêm vào log mỗi rep: `ascent_lean_rise` (góc thân đổ thêm lớn nhất lúc đứng lên). Lớp debug trên màn
  hình hiện "thân đổ thêm X°" thay cho "đồng bộ 1,00x".
- Test mới trong `squat_form_test.dart`: thân giữ 33° lúc đứng lên rồi dựng dần thì không lỗi; thân đổ
  từ 33° lên 48° thì có lỗi, `ascent_lean_rise` = 15°; 3 khung đầu đứng chéo camera thì không báo lỗi.
  Sửa test cũ trong `squat_post_rep_voice_test.dart` cho cách đo mới.
- Ngưỡng 6° / 10° là ước lượng, log cũ không có góc thân từng khung để đo lại. Cần test trên máy, đọc
  `ascent_lean_rise` của rep đúng và rep cố tình đẩy hông lên trước.

### 5.14 Glute Bridge: đếm rep khi hông chưa về sàn (22/11)

- Hiện tượng (`175551Z`): set 1 đếm 11 rep trong 14 s, set 2 đếm 11 rep trong 6,7 s. Set 2 từ rep 2 tới
  rep 11 cách nhau 0,2–0,5 s.
- Nguyên nhân: ngoài đường chính (hạ xuống, nằm yên ở sàn thì tính rep), máy trạng thái còn đường tắt
  "đang hạ → nâng lên lại thì tính rep", không đòi hông về gần sàn. Đo từ sự kiện `phase`: set 1 có
  4/11 rep đếm qua đường tắt, lúc đó hông ở 733–763 px trong khi sàn là 806 px và đỉnh 674–694 px (mới hạ
  khoảng nửa đường). Set 2 có 9/11 rep qua đường tắt, hông ở 653–706 px, sàn 794 px, đỉnh 658–699 px:
  hông gần như vẫn ở đỉnh.
- Sửa (`glute_bridge.dart`): trong lúc hạ, ghi điểm hông thấp nhất. Đường tắt chỉ tính rep khi điểm này đã
  về gần sàn: cách mức nằm không quá max(0,12 chiều dài thân, 30% độ cao đã nâng). Chưa về gần sàn thì
  lần nâng lại được coi là tiếp tục rep đang làm, không đếm thêm. Nếu rep tiếp tục đó kết thúc bằng hông
  nằm yên ở sàn mà app không bắt được pha hạ, rep vẫn được tính.
- Test mới `glute_bridge_rep_count_test.dart`: nâng, hạ nửa đường, nâng lại 2 lần rồi hạ hẳn thì đếm 1
  rep (code cũ đếm 3); chạm sàn rồi nâng ngay 3 lần thì vẫn đếm đủ 3 rep.
- Log cũ không có độ cao hông từng khung nên không chạy lại được để ra số rep mới. Cần test trên máy.

### 5.15 Wall Push-up: 1 lần chống đẩy bị đếm thành 2 rep (22/11)

- Hiện tượng (`175551Z` set 2): rep 3 (khuỷu thấp nhất 129°, hạ 0,24 s) được đếm lúc 11,10 s, rep 4 bắt
  đầu hạ 0,10 s sau đó ở 117,7° và xuống tới 117°. Rep 8 (thấp nhất 124,5°) được đếm khi khuỷu nhảy từ
  124,5° lên 145,2° trong 1 khung (39 ms), rep 9 bắt đầu 0,07 s sau ở 110,6° và xuống tới 84°. Cả hai cặp
  là 1 lần hạ người bị tách đôi. Rep 3 chính là rep "khuỷu chỉ 129° vẫn tính đúng form" ghi ở mục 6.
- Nguyên nhân: khuỷu ≤ 132° là đáy, > 136° là bắt đầu đẩy, > 138° là xong rep, mỗi bước chỉ cần 1 khung.
  Khuỷu của người tập lúc thẳng tay đo được khoảng 157°, nên dải 132–138° nằm giữa đường đi. Đang hạ mà
  dừng một nhịp hoặc điểm khớp nhiễu làm khuỷu mở thêm 10–20° là đủ để app đếm xong 1 rep, phần hạ còn
  lại thành rep thứ hai.
- Sửa (`wall_push_up.dart`):
  - Rep chỉ xong khi khuỷu mở > max(138°, góc thấp nhất của rep + 25°). Rep sâu (≤ 113°) vẫn xong ở 138°
    như cũ; rep nông 129° phải mở tới 154°.
  - Đang đẩy lên mà khuỷu gập lại ≤ 132° thì quay về pha đáy, rep vẫn là rep đó và góc thấp nhất được
    cập nhật.
  - Hệ quả: lúc mới bắt đầu hạ mà khuỷu nhiễu lên 139° (set 2 lúc 20,26–20,36 s) không còn bị coi là
    bỏ dở rep và nhắc "Xuống thấp hơn" nữa.
- Test mới trong `wall_push_up_form_test.dart`: hạ tới 129°, mở lên 142° rồi hạ tiếp tới 117° là 1 rep,
  góc thấp nhất 117° (code cũ đếm 2); khuỷu nhảy 124° → 145° → 141° 1–2 khung ở đáy rồi xuống 85° là 1
  rep; rep nông 128° rồi duỗi về 158° vẫn được đếm.
- Ước tính trên log `175551Z` set 2 theo các mốc trong sự kiện `phase`: 10 rep thành 8. Chưa chắc hẳn vì
  log không ghi góc khuỷu lúc duỗi giữa các rep: rep 5 (thấp nhất 126°) cần khuỷu mở tới 151° mới xong.
  Set 1 rep 10 (thấp nhất 123°, bắt đầu 0,19 s sau rep 9) chưa rõ là rep thật hay nhiễu.
- Giới hạn: người duỗi tay tối đa chỉ khoảng 150° mà mỗi rep chỉ gập tới 130° sẽ không được đếm (biên
  độ 20°, chưa phải một lần chống đẩy).
- Kiểm tra 5.13–5.15: analyze sạch trên các file đã sửa; toàn bộ test 777 qua, 14 bỏ qua. Chưa thử lại
  trên máy.

### 5.16 Ba bài mới: Step-up, Giãn cổ nghiêng, Chống đẩy xoay người (22/11)

Ba bài thêm vào danh sách 24 bài hiển thị, trạng thái "Chỉ đếm, chưa kiểm chứng" (không nằm trong
`validatedExerciseIds`). Catalog để `isFormChecked: false` nên bộ gợi ý giáo án không tự xếp ba bài
này vào lịch; người dùng mở từ Thư viện. Chưa có video mẫu: màn giới thiệu ẩn ô video (`videoAsset`
để trống). Chưa có file giọng: app im lặng ở các câu nhắc riêng của bài, các câu chung (đếm số, bắt
đầu, nghỉ) vẫn phát.

**Nguồn ngưỡng.** Chưa con số nào được đo trên máy. Một số lấy từ tài liệu tập luyện chung (ghi
"tài liệu"), số còn lại là ước lượng hình học từ tỉ lệ cơ thể (ghi "ước lượng"), phải chỉnh sau
khi test thật. Mọi khoảng cách tính theo chiều dài vai–hông phía gần camera ("thân").

#### Step-up (`lib/exercise/step_up/step_up.dart`)

- Camera nhìn nghiêng. Chỉ dùng vai, hông, gối, cổ chân phía gần camera (`SideTrackedExerciseMixin`).
  Không đòi điểm chân phía xa: ghế che chân xa thì app không chặn "thiếu sáng" (khác Lunge, mục 6).
  Gối chân xa chỉ được dùng khi đủ tin cậy.
- Mốc: lúc giữ yên 3 giây ở tư thế đứng, ghi độ cao hông và cổ chân ở sàn. Khi đứng yên trên sàn
  (hông lệch mốc ≤ 0,05 thân) mốc được cập nhật chậm.
- Đếm 1 rep: hông lên ≥ 0,12 thân trong 2 khung (bắt đầu bước lên) → hông lên ≥ 0,30 thân và gối
  (gần hoặc xa) ≥ 155° trong 3 khung (đứng thẳng trên ghế) → hông về ≤ 0,08 thân trong 3 khung (về
  sàn) thì tính rep. Ngưỡng lên 0,30 và ngưỡng về 0,08 cách nhau xa nên một lần bước không thể bị
  đếm đôi (bài học 5.15). Lên được một chút rồi về sàn mà chưa đạt điều kiện trên ghế thì không tính,
  log `noCount` là `height` (chưa lên đủ cao) hoặc `knee` (đủ cao nhưng gối chưa thẳng).
- Đổi chân: lúc bắt đầu bước lên, cổ chân gần camera đã nhấc ≥ 0,20 thân thì chân gần là chân bước,
  ngược lại là chân xa. Bước cùng chân 2 lần liền ghi lỗi `alternate`, không trừ điểm form, không có
  giọng nhắc (nhận chân dễ sai nên chỉ ghi lại).
- Lỗi form: thân đổ > 30° so với phương thẳng đứng trong 3 khung khi đang ở trên ghế (`trunk`).
- Nguồn: gối duỗi gần thẳng ở đỉnh (tài liệu, ngưỡng 155° là ước lượng); ghế 30–45 cm thường dùng
  cho step-up nên hông lên khoảng 0,6–0,9 thân, ngưỡng 0,30 thân (khoảng 15 cm) là mức thấp nhất
  cho bậc thấp (ước lượng); 0,12 / 0,08 / 0,20 / 30° (ước lượng). MET 5,0 lấy theo Lunge trong
  `report_builder_registry.dart`.
- Số liệu mỗi rep: `max_hip_rise`, `top_knee_angle`, `max_trunk_lean`, `lead_leg`. Set: `no_count_attempts`.

#### Giãn cổ nghiêng (`lib/exercise/neck_side_stretch/neck_side_stretch.dart`)

- Khung giữ có sẵn (`RepCountedHoldExercise`). Mặc định 2 lần giữ × 20 s, lần 2 phải đổi bên. Camera
  nhìn chính diện; quay hẳn nghiêng thì nhắc "quay mặt về camera".
- Góc nghiêng đầu = góc giữa đường nối hai tai và đường nối hai vai (tai không rõ thì dùng hai mắt).
  Dấu của góc cho biết nghiêng về bên nào, không phụ thuộc ảnh có lật gương hay không.
- Chống nhiễu: làm mượt góc (hệ số 0,35 mỗi khung); khung nào góc nhảy > 25° so với góc đã làm mượt
  thì bỏ qua (tối đa 2 khung liền, khung thứ 3 mới nhận); mất điểm tai/mắt tối đa 6 khung thì dùng lại
  góc cũ; ra khỏi tư thế phải đủ 3 khung liền. Test: 2 khung nghiêng ngược −35°, 1 khung 0°, 2 khung
  mất tai đều không làm đứt lượt giữ.
- Đồng hồ chạy khi: góc ≥ 25° (vào), dừng khi < 18° (ra); đúng bên; vai không nghiêng theo (góc đường
  vai lệch mốc lúc bắt đầu ≤ 10°); không nhún vai (khoảng cách dọc vai–hông tăng ≤ 8% so với mốc).
  Nghiêng vai và nhún vai phải kéo dài 6 khung mới tính, lúc đó ghi lỗi `shoulder` / `shrug` cho lần
  giữ đó và dừng đồng hồ.
- Nguồn: cổ nghiêng bên bình thường khoảng 45° (tài liệu), ngưỡng vào 25° là khoảng nửa tầm đó (ước
  lượng); giữ giãn tĩnh 10–30 s (tài liệu, ACSM), chọn 20 s; 18°, 10°, 8% (ước lượng). MET 2,3 cho giãn
  cơ nhẹ (tài liệu, Compendium of Physical Activities).
- Ở 3 m đầu rất nhỏ: chưa biết điểm tai rung bao nhiêu độ trên máy thật. Mỗi lần giữ ghi `hold_side` và
  `max_tilt`; khung `phase` có `neckTilt`, `shoulderTilt`, `shrugRise`.

#### Chống đẩy xoay người (`lib/exercise/push_up_rotation/push_up_rotation.dart`)

- Camera nhìn nghiêng. Pha chống đẩy dùng lại ngưỡng của `PushUpConfig` (`lib/exercise/push up/`):
  góc khuỷu vai–khuỷu–cổ tay phía gần camera, mốc tay thẳng ≥ 160°, bắt đầu xuống khi khuỷu gập hơn
  mốc 30°, đáy khi khuỷu ≤ 115°, tư thế bắt đầu khuỷu ≥ 155° và thân ≥ 160°. Lên lại khi khuỷu mở hơn
  điểm sâu nhất 15° (đếm theo điểm sâu nhất của rep, bài học 5.15), xong pha đẩy khi khuỷu trong khoảng
  15° dưới mốc. Mỗi bước cần 2 khung liền.
- Pha xoay: cổ tay cao nhất cao hơn vai trên ≥ 0,6 thân và hai vai chồng dọc (chênh độ cao ≥ 0,35 thân,
  lớn hơn chênh ngang) trong 3 khung. Về lại khi cổ tay không còn cao hơn vai quá 0,25 thân và hai vai
  chênh ≤ 0,2 thân trong 3 khung, lúc đó tính rep. Vai phía xa chỉ cần có mặt (presence), không cần rõ.
- Không tính: chống đẩy không tới đáy (log `noCount: depth`, đếm `shallow_attempts`); chống đẩy xong
  mà bắt đầu chống đẩy tiếp chưa xoay (log `noCount: rotation`, đếm `no_rotation_attempts`). Xoay mà
  chưa chống đẩy thì bỏ qua.
- Đổi tay: tay mở lấy theo nhãn trái/phải của cổ tay cao nhất. Mở cùng tay 2 lần liền ghi `alternate`,
  không trừ điểm form, không có giọng nhắc (nhãn trái/phải của MediaPipe ở góc nghiêng có thể bị đảo).
- Lỗi form: vai–hông–cổ chân < 150° trong 4 khung khi đang chống đẩy (`body_line`, ngưỡng của Push-up).
- Mốc tay thẳng chỉ cập nhật khi khuỷu nằm trong 8° dưới mốc. Lý do: bản đầu cập nhật mốc ở mọi khung
  ≥ 160°, nên lúc bắt đầu hạ người mốc tụt theo và rep nông không bao giờ vào pha xuống (bắt được bằng
  test rep nông).
- Nguồn: khuỷu khoảng 90° ở đáy chống đẩy (tài liệu, ACSM), các ngưỡng góc khuỷu lấy nguyên từ
  `PushUpConfig`; 0,6 / 0,35 / 0,25 / 0,2 thân và 15° (ước lượng). MET 3,8 lấy theo Push-up.

**Test** (mô phỏng pose, không phải video thật): `test/exercise/step_up_test.dart` (4 test: rep đúng;
bước nửa chừng không tính; che hông/gối/cổ chân phía xa vẫn đếm 2 rep, kể cả rep bước bằng chân xa;
cùng chân 2 lần), `neck_side_stretch_test.dart` (5 test: giữ 30° đủ giờ; lần 2 bắt buộc đổi bên;
nghiêng 15° không chạy đồng hồ; nhiễu đầu 1–2 khung không đứt; nhún vai dừng đồng hồ và ghi lỗi),
`push_up_rotation_test.dart` (4 test: rep đủ; rep nông không tính; thiếu xoay không tính; đổi tay).
Sửa số trong các test cũ: 21 → 24 bài giữ, 40 → 43 dòng catalog/seed; thêm khóa báo cáo mới vào
`report_builder_key_contract_test.dart`.

**Nối dây:** `exercise_definition.dart`, `exercise_lookup.dart` (alias), `kept_exercises.dart`,
`exercise_catalog.json`, `supabase/seed.sql`, `report_builder_registry.dart` (calorie dùng MET chung,
không cần dòng trong `calorie_estimator_registry.dart`), `camera_placement_card.dart`,
`generic_exercise_voice_assets.dart`, `library_mock.dart` (Giãn cổ nằm trong nhóm "Yoga & phục hồi"
nhưng không gắn cờ yoga), `docs/reference/voice-coach/missing-audio.md` (dòng 184–195).

**Giọng nói còn thiếu:** 12 file ở dòng 184–195 của bảng `missing-audio.md`. Sau khi tạo file, thêm
`assets/audio/step_up/`, `assets/audio/neck_side_stretch/`, `assets/audio/push_up_rotation/` vào
`pubspec.yaml` (chưa thêm, vì khai báo thư mục chưa có file làm build lỗi).

**Kiểm tra:** `flutter analyze` trên các file đã sửa: không có lỗi. Toàn bộ test 798 qua, 14 bỏ qua
(777 trước đó, 13 test mới, 8 test của việc khác đang làm dở trong checkout). Chưa thử trên máy.

### 5.17 Lunge: đổ người về trước không bị bắt lỗi (P00, 24/11)

- Hiện tượng (log `20261123T172851Z-P00`): 10 rep, rep 1–5 tập đúng, rep 6–10 cố ý đổ người về trước.
  App đếm 10/10 nhưng không ghi lỗi `trunk` nào, không có giọng nhắc.
- Số đo trong log (`max_trunk_lean` mỗi rep): rep đúng 10,6° / 5,4° / 2,8° / 7,3° / 3,7°; rep đổ người
  37,1° / 45,9° / 33,2° / 26,9° / 31,3°. App đo đúng, hai nhóm tách rõ.
- Nguyên nhân: ngưỡng cũ trong `metrics/lunge_trunk_lean_metric.dart` chỉ ghi lỗi khi thân nghiêng
  ≥ 56° liền 12 khung (khoảng 0,65 s ở 18 khung/s). 46–55° chỉ hiện chữ trên màn hình, không ghi lỗi.
  Không rep nào tới 56°.
- Sửa: nghiêng ≥ 20° liền 5 khung (khoảng 0,27 s) là lỗi `trunk`; 15–19° chỉ hiện chữ "Hơi gập người";
  dưới 15° là "Lưng tốt". Ngả ra sau giữ nguyên (< −10° liền 8 khung).
- Ngưỡng 20° là ước lượng từ một người tập (P00): rep đúng cao nhất 10,6°, cách ngưỡng khoảng 9°. Cần
  xem lại khi có log của người khác.
- Chưa sửa: khi thân đổ, có khung app tưởng người đứng chéo camera và đọc góc thân = 0 (đầu rep 7 trong
  log). Khung đó làm đứt chuỗi 5 khung.
- Test mới trong `lunge_form_test.dart`: 20° liền 5 khung là lỗi; 11° không lỗi; 46° chỉ 4 khung rồi về
  0° không lỗi. 12/12 test lunge qua, analyze sạch.
- Thử lại trên máy (log `20261123T173951Z-P00`): rep 6, 8, 9, 10 đổ người (21–29°) đều bị ghi `trunk`
  và có giọng nhắc; rep 1–5 và rep 7 tập đúng (−2° tới 9°) không bị báo.

### 5.18 Jump Squat: nhún nông không được tính rep, app kẹt ở pha "lơ lửng" (P00, 24/11)

- Hiện tượng (log `174127Z`, `174210Z`, `174342Z`, cùng P00): kịch bản 12 rep, app đếm 1, 5 và 10. Lần
  1 kẹt ở pha "lơ lửng" 8 s; lần 2 sau rep 5 không ghi lần lấy đà nào trong 13 s (lúc tập rep nhún
  nông), rồi kẹt "lơ lửng" 35 s; lần 3 kẹt ở pha "tiếp đất" tới 7,5 s rồi lấy một lần đung đưa làm cú
  nhảy mới.
- Nguyên nhân 1: app chỉ vào pha "lấy đà" khi gối < 140°, và chỉ từ pha đó mới sang được pha "lơ
  lửng". Nhún nông hơn 140° thì không có rep, cũng không có lỗi `takeoff_depth` (ngưỡng lỗi 125°).
- Nguyên nhân 2: mốc mặt sàn là độ cao bàn chân lúc bắt đầu, chỉ cập nhật khi đứng thẳng và chân
  lệch mốc dưới nửa ngưỡng bay (vài pixel). Tiếp đất xa hoặc gần camera hơn chỗ bật vài cm là bàn chân
  trong ảnh lệch khỏi mốc, app coi như chưa chạm đất và mốc không bao giờ tự sửa. Log lần 2 có lúc
  chân lệch mốc 144 px khi đang đứng.
- Sửa (`jump_squat.dart`):
  - Vào pha "lấy đà" khi gối < 160° (trước 140°); về pha đứng khi gối > 165° (trước 150°), để hai ngưỡng
    không chồng nhau. Cú nhảy từ tư thế nhún nông giờ được đếm và bị ghi `takeoff_depth` nếu gối
    không gập quá 125°.
  - Tiếp đất khi: chân về mốc sàn như cũ, hoặc chân đã rơi xuống khỏi điểm cao nhất hơn một ngưỡng bay
    rồi dừng lại, hoặc đã "lơ lửng" quá 0,8 s. Hai trường hợp sau đặt lại mốc sàn theo chỗ chân vừa
    chạm.
  - Đứng hoặc tiếp đất với gối > 165°, hông và chân yên (lệch < 3% chiều dài thân) liền 8 khung thì đặt
    lại mốc sàn (và mốc hông nếu gối ≥ 170°) theo vị trí hiện tại.
- Ngưỡng 160° / 165°, 0,8 s, 8 khung, 3% là ước lượng, chưa đo trên máy.
- Không làm: cho nhảy thẳng từ pha đứng sang "lơ lửng" mà không qua "lấy đà". Cú bật gối gần thẳng
  (gối không xuống dưới 160°) vẫn không được tính.
- Test mới trong `jump_squat_form_test.dart`: nhún tới 150° rồi bật được đếm và ghi `takeoff_depth`;
  tiếp đất cao hơn mốc 20 px vẫn đếm rep; "lơ lửng" quá 1 s thì thoát; đứng yên ở chỗ mới 10 khung thì
  mốc sàn và hông về 0. 115 test trong 5 file có dùng Jump Squat qua (5 bỏ qua), analyze sạch.
- Thử lại trên máy (log `20261123T180542Z-P00`): đếm 12/12, không kẹt pha nào. Nhưng lỗi bắt sai, xem
  5.19.

### 5.19 Jump Squat: nhún nông, tiếp đất nông, nhảy nhẹ vẫn được tính "đúng" (P00, 24/11)

- Số đo (log `180542Z`, góc gối nhỏ nhất): rep đúng 1–6 lấy đà 85–96°, tiếp đất 61–91°. Rep nhún nông
  7–9 lấy đà 101°, 105°, 107°. Rep bật thấp 10–12 lấy đà 121°, 104°, 91°, tiếp đất 118°, 107°, 134°.
  App chỉ ghi `landing_stiff` ở rep 9 (tiếp đất 155°); các rep còn lại có `landing_depth` nhưng lỗi này
  không tính sai form, nên 11/12 rep "đúng".
- Nguyên nhân: ngưỡng `takeoff_depth` là 125°, không rep nào tới. `landing_depth` (tiếp đất 105–145°)
  là cảnh báo, không làm rep sai. Không có metric nào đo độ cao bật.
- Sửa:
  - `metrics/take_off_depth_metric.dart`: lấy đà mà gối không gập tới 100° là lỗi `takeoff_depth`
    (trước 125°).
  - `metrics/landing_knee_flexion_metric.dart`: `landing_depth` (tiếp đất 105–145°) giờ tính sai form.
    Giọng nhắc đổi từ câu khen nhẹ `landing_depth_soft.mp3` sang `landing_stiff.mp3` ("tiếp đất nhẹ, trùng
    gối để giảm sốc"), qua `generic_exercise_voice_assets.dart`.
  - Log mỗi rep thêm `takeoff_knee`, `landing_knee` (độ) và `jump_height_ratio` (hông nâng cao nhất khi
    bay so với lúc đứng, chia chiều dài thân). Chưa có lỗi theo độ cao bật, cần số liệu trước.
- Với log này, ngưỡng mới bắt rep 7–11; rep 1–6 vẫn đúng. Rep 12 lấy đà 91° nên chỉ bị bắt nếu góc
  tiếp đất nhỏ nhất > 105° (log chỉ có 134° lúc vừa chạm đất, không có giá trị nhỏ nhất).
- Rủi ro: ngưỡng lấy đà 100° chỉ cách rep đúng sâu nhất của P00 (96°) 4°. Cần xem lại với người khác.
- Test: lấy đà 105° là lỗi, 90° không; tiếp đất 115° làm rep sai; log rep có 3 trường mới. Sửa fixture
  tiếp đất của test cũ từ 110–115° xuống 95°. Toàn bộ 817 test qua (14 bỏ qua), analyze sạch.
- Thử lại trên máy (log `20261123T182738Z-P00`, tập tự do, P00 xác nhận app chấm đúng): 12 rep, 6
  đúng, 6 sai. Rep đúng: lấy đà 83–94°, tiếp đất 82–96°, `jump_height_ratio` 0,32–0,55. Rep sai: lấy đà
  102–138° hoặc tiếp đất 119–175°, `jump_height_ratio` 0,06–0,25. Nếu sau này thêm lỗi "bật thấp", ngưỡng
  nằm giữa 0,25 và 0,32 với người này; chưa thêm.

### 5.20 Jumping Jack: chân mở hẹp không bị báo, tay qua đầu vẫn bị báo `arms` (P00, 24/11)

- Hiện tượng (log `20261123T183059Z-P00`, kịch bản 20 rep: 1–10 đúng, 11–15 tay không qua đầu, 16–20 chân
  hẹp): app đếm 14. `arms` ở 8 rep, kể cả các rep tay giơ thẳng qua đầu (góc tay 154–180° lúc vào pha
  mở); `legs` chỉ ở rep 14.
- Nguyên nhân 1: lỗi `arms` trong code là "khuỷu tay gập < 105° liền 3 khung", không phải "tay chưa qua
  đầu" như danh mục lỗi và file giọng `arms.mp3` ("vung tay lên cao qua đầu"). Lỗi bật ở đúng lúc tay
  giơ cao (0,1–0,4 s sau khi vào pha mở), nghi do khung xương cổ tay, khuỷu tay vẽ lệch khi tay vung
  nhanh; log không có góc khuỷu từng khung để kiểm.
- Nguyên nhân 2: pha mở đòi cả hai cổ tay cao hơn mũi và chân mở > 1,0 lần vai. Rep tay thấp hoặc chân
  quá hẹp không vào pha mở nên không được đếm (khoảng trống 9 s sau rep 8 và 6 s sau rep 11), vì vậy
  không thể có lỗi. Rep chân hẹp mà vẫn vào pha mở (1,13–1,23 lần vai lúc vào pha) thường có đỉnh vượt
  1,25 nên không bị `legs`.
- Sửa:
  - Pha mở: chân > 0,85 lần vai (trước 1,0) và tay trung bình > 90° (trên vai); bỏ điều kiện cổ tay cao
    hơn mũi. Rep tay thấp, chân hẹp giờ được đếm để chấm lỗi.
  - `metrics/arm_extension_metric.dart`: bỏ kiểm tra khuỷu tay. `arms` = góc tay cao nhất trong rep (lấy
    bên thấp hơn) < 150°. Màn tập hiện "Vung tay cao qua đầu!" khi tay chưa tới.
  - `metrics/leg_spread_metric.dart`: `legs` khi chân mở rộng nhất < 1,4 lần vai (trước 1,25).
  - Log mỗi rep thêm `peak_arm_elevation`, `peak_ankle_spread`.
  - `exercise_experience_screen.dart`: chú thích "Khuỷu tay ≥ 135°" ở màn giới thiệu bài đổi thành
    "Tay nâng ≥ 150°".
- Ngưỡng 150° và 1,4 là ước lượng: log cũ chỉ có góc lúc vào pha mở (rep đúng: tay 154–180°, chân
  1,26–1,74), không có giá trị lớn nhất. Cần tập lại để đọc `peak_*`.
- Test: chân 0,95 và 1,3 lần vai được đếm và có `legs`; tay chỉ tới ngang vai được đếm và có `arms`;
  khuỷu gập mà tay vẫn qua đầu không còn lỗi. 818 test qua (14 bỏ qua), analyze sạch. Chưa thử trên máy.

### 5.21 Chỉ đo 21 bài (24/11)

- Quyết định của nhóm: đợt đo chỉ gồm 21 bài. `step_up`, `neck_side_stretch`, `pushup_rotation` (thêm
  22/11, chưa đo ngưỡng trên máy, thiếu giọng nói) bỏ khỏi `fault_catalog.csv`, `cue_fault_map.csv`,
  `HUONG_DAN_GAN_NHAN.md`, `KICH_BAN_P00.md`, `KE_HOACH_THU_SO_LIEU.md`. Cùng ngày ẩn luôn khỏi app: bỏ khỏi `keptExerciseIds` và
  `kExercisePlacementByCatalogId` (code của bài vẫn giữ để bật lại); app còn 21 bài. Sửa số đếm 24/19 thành
  21/22 trong 3 file test (`kept_exercises_allowlist_test`, `camera_setup_guide_test`,
  `kept_exercises_launch_and_labels_test`).
- `p00_gate.py` chỉ xét hiệp mới nhất (đã có tiếng bíp) của mỗi bài ở mỗi điều kiện, để hiệp tập lại sau
  khi sửa thay hiệp cũ.

### 5.22 Màn nghỉ phát lại rep đúng cạnh rep sai (24/11, tính năng mới)

- Ý tưởng của nhóm: ở màn nghỉ, phát lại rep tập đúng bên cạnh rep tập sai. Hiệp đúng hết thì không hiện;
  nhiều loại lỗi thì nhiều cặp (tối đa 3).
- Cách làm, giữ FPS lúc tập:
  - Android (`RepReplayBuffer.kt`, gọi trong `PoseLandmarkerPlugin.analyzeFrame`): khoảng 10 lần/giây thu
    nhỏ khung ảnh mà app vốn đã tạo cho MediaPipe xuống 320 px, giữ 4 s gần nhất trong RAM. Không mở thêm
    camera, không ghi video, không nén lúc đang tập.
  - Dart (`lib/services/rep_replay.dart`): mỗi rep xong, đánh dấu đoạn từ rep trước tới rep này (0,8–3,5
    s). Giữ rep đúng gần nhất và rep sai đầu tiên của mỗi loại lỗi mới (bỏ lỗi đã "Báo sai" và rep không
    chấm form).
  - Màn nghỉ (`lib/widgets/rep_replay_view.dart`): lúc này mới nén JPEG (luồng phụ) rồi phát lặp chậm
    0,5×, rep đúng viền xanh bên trái, rep sai viền cam bên phải, ghi số rep và câu lỗi.
  - Ảnh chỉ trong RAM, không lưu file, không tải lên mạng; xoá khi sang hiệp mới hoặc rời bài.
- Không hiện ở điều kiện `control`. iOS chưa có phần native nên không hiện gì. Tắt toàn bộ bằng
  `kRepReplayEnabled` trong `lib/services/rep_replay.dart`.
- Điều kiện `ai` của đợt đo giờ có thêm phản hồi này: phải ghi vào báo cáo.
- Kiểm tra: 6 test mới (`test/services/rep_replay_test.dart`), 824 test qua (14 bỏ qua), analyze sạch,
  `flutter build apk --profile` thành công. Chưa chạy trên máy: chưa đo FPS, chưa xem hình có đúng chiều
  và đúng đoạn rep không.
- Thử trên máy (log `20261123T192334Z-P00`, squat 2 hiệp): P00 thấy video chậm, và thấy "từ rep 2 trở đi
  check hơi lag". Đã sửa video về tốc độ thật (1×), mỗi clip chỉ nén một lần dù hiện ở nhiều ô.

### 5.23 Giọng đếm rep phát trễ sau lời nhắc lỗi (P00, 24/11)

- Đo FPS từ logcat (`perf` mỗi 3 s): hiệp 1 (đang ghi hình cho phát lại) 17,5–20,2 kết quả/s, suy luận
  77–86 ms; hiệp 2 lúc tập 16,6–19,7/s, 80–91 ms. Không thấy tụt FPS do phát lại; mức tụt nhỏ ở hiệp 2
  nằm trong dao động, nghi máy nóng.
- Cái "lag" thật là giọng đếm: số rep phải chờ lời nhắc lỗi đang phát xong. Hiệp 1: rep 2 đếm trễ 1,2 s
  (sau `trunk.mp3`), rep 3 trễ 1,3 s (sau `trunk_reminder.mp3`). Hiệp 2 (đổ người gần như mọi rep): rep 2
  trễ 2,3 s, rep 6 trễ 2,5 s, rep 7 trễ 1,1 s. App vẫn đếm đúng lúc trên màn hình; chỉ giọng bị lùi.
- Sửa (`policy_voice_coach.dart`): giọng đếm của rep (không phải rep cuối) chỉ phát nếu bắt đầu được trong
  0,8 s sau rep (`maxCountDelayMs`); trễ hơn thì bỏ, số trên màn hình vẫn đúng. Rep cuối luôn đọc.
- Test mới `test/voice/count_staleness_test.dart`. 826 test qua (14 bỏ qua), analyze sạch, build APK
  profile thành công. Chưa thử lại trên máy.

### 5.24 Sit-up: lên nửa chừng không báo lỗi, nhấc chân không báo, màn hình không nói đang chấm gì (P00, 24/11)

- Hiện tượng (log `20261123T200048Z-P00`, kịch bản 1–5 đúng, 6–8 lên nửa chừng, 9–10 nhấc chân): app đếm
  10, `rom` 0 lần, `stability` ở rep 2, 6, 9. Màn tập không có dòng chữ nào ngoài tên pha. P00 báo thêm:
  rep lên nửa chừng có lúc không được đếm.
- Nguyên nhân:
  - `rom` không thể xảy ra: lỗi cần góc gối–hông–vai nhỏ nhất > 142°, nhưng rep chỉ được đếm khi góc đó
    ≤ 142° (hoặc ≤ 105° để vào pha "lên").
  - Rep chỉ bắt đầu khi thân rời sàn > 30°; lên nửa chừng thấp hơn thì không đếm, không báo.
  - Nhấc chân đo bằng độ dịch 2 chiều của mắt cá > 22% chiều dài thân, mốc lấy lúc bắt đầu lên: nhấc
    vài cm không tới ngưỡng.
  - Các metric không ghi chữ nào ra màn hình; `debugData` trống nên log không có số đo.
- Sửa (`2.Sit-Up/sit_up.dart`, `metrics/rom_metric.dart`, `metrics/stability_metric.dart`):
  - Pha theo góc thân so với sàn: nằm < 15°, bắt đầu lên > 20°, "đã lên" ≥ 60°, hạ khi thân thấp hơn đỉnh
    10°. Về nằm thì tính 1 rep nếu đỉnh ≥ 30°; dưới 30° (chỉ nhấc vai) không tính.
  - `rom`: đỉnh thân < 60° là lỗi "Chưa ngồi lên hết: thân mới lên X°".
  - `stability`: mốc là độ cao mắt cá lúc nằm (trung bình động); mắt cá cao hơn mốc > 10% chiều dài thân
    liền 3 khung là lỗi "Nhấc chân khỏi sàn".
  - Màn tập hiện chữ: "Cuộn người lên cao hơn" / "Đã lên đủ cao", "Chân tốt" / "Giữ chân trên sàn". Pha trên
    cùng đổi tên "Giữ!" thành "Đã lên, hạ xuống".
  - Log: mỗi khung có `trunk`, `khs`, `peakTrunk`; mỗi rep có `peak_trunk`, `max_ankle_lift`.
- Ngưỡng 60°, 30°, 10% là ước lượng, log cũ không có góc thân. Câu giọng `sit_up/stability.mp3` ("lên
  xuống đều, giữ người ổn định") chưa nói rõ về chân; cần thu lại.
- Test: thân 50° được đếm và có `rom`; ngồi thẳng chân yên không lỗi, nhấc mắt cá 25% thân có
  `stability`; nhấc vai 25° không tính rep. 828 test qua (14 bỏ qua), analyze sạch, build APK profile
  thành công. Chưa thử trên máy.
- Thử trên máy (log `20261123T203009Z-P00`): `rom` ở rep 1, 3, 4, 6 (đỉnh thân 35–60°), rep đúng đỉnh
  62–77°. `stability` ở rep 2 (mắt cá nhấc 0,13). Rep đúng có độ nhấc mắt cá 0,07–0,11, sát ngưỡng 0,10;
  rep 9–10 (kịch bản nhấc chân) chỉ 0,10 và 0,07 nên không bị bắt. Cần xem P00 nhấc chân thế nào trước
  khi đổi ngưỡng.

### 5.25 Màn nghỉ hiện mã lỗi thay vì tên; plank 3 lượt chỉ tính 1; video chỉ 1 dù nhiều lỗi (P00, 24/11)

- Tên lỗi: thẻ "CẦN CHÚ Ý" ở màn nghỉ chỉ có tên tiếng Việt cho vài mã squat cũ; mã khác hiện nguyên mã
  ("rom"). Sửa: lấy câu lỗi của chính bài (`setFeedback`), bỏ phần số sau dấu ":" hoặc "(" làm tên
  (`faultTitlesFromSetFeedback` trong `lib/services/rep_replay.dart`), truyền vào `RestScreen.faultTitles`.
- Plank (log `20261123T203133Z-P00`): lượt 1 giữ được 11,8 s thì thân lệch quá giới hạn, lượt 2 được
  13,6 s thì gối co 133°; cả hai về "chuẩn bị" và đồng hồ về 0, không tính. Lượt 3 đủ 15 s và mang cả 3 lỗi.
  Đồng hồ của app chậm hơn cảm nhận người tập: 3 s giữ yên để bắt đầu không được tính vào lượt 1, và app
  không đọc đếm ngược nên người tập tự đếm rồi dừng sớm.
  - Sửa (`plank/plank.dart`): lượt kết thúc khi đã giữ ≥ 12 s (thiếu ≤ 3 s) vẫn tính, `hold_time` ghi số
    giây thật (trước luôn ghi 15); lượt đầu ngay sau khi bắt đầu được cộng 3 s giữ yên; mất khung hình
    hoặc mất điểm khớp cũng áp dụng cùng quy tắc.
  - `plank_voice_coach.dart`: đọc "3, 2, 1" ở 3 giây cuối mỗi lượt.
- Video phát lại: trước chỉ lấy 1 clip cho mỗi mã lỗi, nên plank võng (`Back`) và vểnh (`Back`) chỉ có 1
  video, và 1 lượt plank nhiều lỗi chỉ là 1 video. Sửa: mỗi cặp (mã lỗi, tên lỗi) khác nhau có clip riêng,
  tối đa 3. Một lượt giữ vẫn là một clip (3,5 s cuối lượt).
- Test mới: tên lỗi bỏ số; thẻ lỗi hiện "Chưa ngồi lên hết" thay vì "rom"; `Back` võng và `Back` vểnh có 2
  clip; plank dừng ở 12,5 s được tính với `hold_time` 12,5, dừng ở 8 s không tính, lượt đầu được cộng 3 s.
  834 test qua (14 bỏ qua), analyze sạch, build APK profile thành công. Chưa thử trên máy.

### 5.26 Sáu bài sàn: cầu mông, nâng chân, V-up, McGill, dead bug, dip tay sau (P00, 24/11)

Log `20261123T2039–2048Z-P00`. Ngưỡng mới đều là ước lượng từ một người tập; chưa thử lại trên máy.

- **Cầu mông.** "Vừa vào đã báo lỗi": trước khi bắt đầu, app nói "quay ngang" và "đưa toàn thân vào khung"
  (lời hướng dẫn đặt máy, 30 s mới bắt đầu được). Nhấc hông nhẹ không tính: có 7 lần nâng hông (đỉnh
  cao hơn sàn 62–88 px, có lần bằng rep đúng) bị bỏ vì hạ nhanh quá nên app không kịp thấy pha "hạ".
  Sửa: hông về sàn mà đã nâng ≥ 15% chiều dài thân thì vẫn tính rep; lỗi `hip_extension` (hông thấp) khi
  góc vai–hông–gối < 155° (trước 140°), cảnh báo 155–160°. Log rep thêm `hip_lift_ratio`. `speed_control`
  (cảnh báo nhẹ) bật ở cả 10 rep, chưa sửa.
- **Nâng chân.** `tempo` ("hạ chân thật chậm") bật ở rep hạ 1,0–1,2 s là tốc độ bình thường; rep thấp
  (`rom`) có lúc không có giọng vì giọng lỗi bốc ngẫu nhiên. Sửa: `tempo` khi hạ < 0,8 s (trước 1,2 s).
- **V-up.** `tempo` bật ở 5/6 rep (hạ 0,63–0,97 s); `rom` gần như không thể bật (cần góc > 135° và tay xa
  chân, lại chỉ là cảnh báo); `knee` không thể bật vì co gối dưới 130° thì app không cho vào pha "lên".
  Sửa: `tempo` < 0,5 s; `rom` khi góc vai–hông–cổ chân nhỏ nhất > 100°, tính sai form; đếm rep khi gối ≥
  90°, lỗi `knee` khi gối < 140°.
- **McGill.** "Thả lỏng cổ" ở mọi rep: độ lệch góc tai–vai–hông so với lúc nằm là 22–48°, nhưng phần lớn
  là do lưng trên cuộn lên chứ không phải cổ. Sửa: trừ độ nâng thân khỏi độ lệch, chỉ chấm khi thân đã
  nâng ≥ 5°, ngưỡng 15° (cảnh báo) / 20° (lỗi).
- **Dead bug.** `floor_contact` ("giữ tay chân trên không") ở 7/8 rep: metric coi tay hoặc chân duỗi ≥ 165°
  là chạm sàn, nhưng duỗi thẳng chính là động tác đúng. Camera 2 chiều ở 3 m không phân biệt được tay
  cách sàn vài cm. Tắt lỗi này (`FloorContactMetric.enabled = false`). `tempo` < 0,5 s (trước 0,8 s). Lỗi
  cùng bên / không đổi bên dựa vào tay chân phía xa camera, bị che nên không tin được (rep 3 báo sai, rep
  5–8 không bắt): chưa sửa, ghi là giới hạn.
- **Dip tay sau.** Trên sàn khuỷu không gập tới 120° nên không có rep nào; chống tay mép giường thì đếm
  được. Các metric lỗi có sẵn nhưng chưa được nối vào, nên app chỉ đếm rep, không chấm gì. Sửa: nhún
  nông (khuỷu dừng ở 120–140°) giờ được tính rep với lỗi `rom`; `hip_thrust`, `shrug`, `extension` vẫn chưa
  nối. Kịch bản P00 đổi sang chống mép ghế hoặc giường.
- Test sửa và thêm cho từng bài; 837 test qua (14 bỏ qua), analyze sạch, build APK profile thành công.

### 5.27 Lần thử thứ hai: V-up không đếm, McGill đếm đôi, plank, cầu mông, nhân sư, plank nghiêng (P00, 24/11)

Log `20261123T2132–2148Z-P00`. Chưa thử lại trên máy.

- **V-up không đếm rep nào** (lỗi do 5.26): rep có lỗi `knee` bị loại hẳn, và ngưỡng `knee` mới 140° làm mọi
  rep đều có lỗi. Sửa: rep co gối vẫn được đếm và ghi `knee`; ngưỡng `knee` trả về 130°.
- **McGill đếm đôi**: sau mỗi rep, 0,2 s sau đã vào rep mới (điểm vai nhảy, thân chưa về hẳn). Sửa: phải
  nằm yên ≥ 0,6 s mới bắt đầu rep sau. Số rep mỗi hiệp 6 → 10 (`exercise_catalog.json`, `seed.sql`).
- **Plank**: đổi thành 3 hiệp × 1 lượt 20 s, nghỉ 20 s giữa hiệp (trước 1 hiệp × 3 lượt 15 s, nghỉ 5 s).
  Thời lượng lượt lấy từ `seconds` của danh mục (`Plank.holdSeconds`, mặc định 15 cho chỗ khác).
- **Đếm giây bằng giọng cho mọi bài giữ** (plank và các bài giữ chung khung: con bướm, nhân sư, ngồi gập
  người, plank nghiêng…): đọc 1–7 ở đầu lượt, "được một nửa" ở giữa lượt, rồi 5–1 ở 5 giây cuối. Lượt ngắn
  thì đếm tới giữa lượt trừ 1.
- **Cầu mông**: nâng cao hay thấp đều "Tốt" vì góc vai–hông–gối ở rep nâng thấp vẫn 162–167°. Số đo đúng
  hơn là độ nâng hông: rep thấp 0,17–0,20, rep cao 0,25–0,34 chiều dài thân. Sửa: `hip_extension` khi độ
  nâng < 0,22. Lời nói lúc vừa vào bài là hai câu hướng dẫn đặt máy và "quay nghiêng người với màn hình"
  khi app chưa thấy người nằm nghiêng; nội dung file mp3 chưa kiểm được.
- **Nhân sư không báo lỗi**: rụt vai chỉ bị bắt khi khoảng tai–vai < 0,10 chiều dài thân, trong khi đo
  được 0,31–0,38. Sửa: rụt vai khi khoảng tai–vai giảm ≥ 25% so với lúc thả lỏng của chính người tập.
- **Plank nghiêng nằm im cũng đếm**: người nằm nghiêng thẳng trên sàn có thân thẳng giống plank nghiêng.
  Sửa: vai phải cao hơn cổ chân ≥ 12% chiều dài vai–cổ chân mới tính là đang giữ. P00 đã bấm "Bỏ qua cảnh
  báo" nên hiệp đó không chấm form.
- Test mới hoặc sửa cho từng điểm; 840 Flutter + 49 Python test qua, build APK profile thành công.

### 5.26 Gợi ý món ăn theo giờ và theo kcal đã đốt, popup sau buổi tập (24/11, tính năng mới)

- Yêu cầu của chủ dự án: tập bài lẻ trong Thư viện xong thì trang chủ phải cập nhật; về màn hình chính
  thì hiện popup "hôm nay ăn gì", món hợp với số kcal vừa đốt và với giờ tập (sáng, trưa, tối).
- Trước khi sửa: trang chủ chỉ tải lại sau buổi tập theo kế hoạch; mức kcal mỗi bữa luôn là 1/3 nhu cầu
  ngày; cùng một danh sách món cho mọi giờ.
- Cách làm:
  - Mức kcal của bữa = min(nhu cầu ngày / 3 + kcal đã đốt hôm nay, nhu cầu ngày + kcal đã đốt − kcal đã
    ăn). Nhu cầu ngày theo Mifflin-St Jeor × 1,4 (đã có); kcal đốt lấy từ nhật ký ngày, ước theo MET
    (Compendium 2011). Mỗi thực đơn chọn khẩu phần lớn nhất còn nằm trong mức này, nên tập nhiều thì
    phần ăn lớn hơn, đã ăn gần đủ thì phần nhỏ lại.
  - Đạm vẫn 0,25–0,4 g/kg (20–40 g), ISSN 2017.
  - Thực đơn có thêm trường `meals`: sáng (phở, bún bò, mì Quảng, hủ tiếu, xôi giò, bánh mì nem, cơm
    tấm), trưa/tối (các mâm cơm, bún), sau 21 giờ chỉ gợi ý 3 bữa nhẹ mới (sữa tươi + trứng, sữa đậu nành
    + trứng, yến mạch nấu sữa), nguồn ISSN 2017 về ăn đạm trước khi ngủ. Giờ chia bữa theo
    `mealSlotForHour` (trước 10 h sáng, trước 15 h trưa, trước 21 h tối).
  - `workoutFinished` (`workout_summary_screen.dart`) tăng khi rời màn tổng kết, áp dụng cho mọi cách
    mở bài (kế hoạch, Thư viện, bộ bài). Trang chủ tải lại chuỗi ngày, tiến độ tuần và thẻ món;
    `MainShell` mở popup gợi ý món. Không hiện ở điều kiện `control`.
- Kiểm tra: 2 test mới trong `test/nutrition/nutrition_test.dart` (mức kcal, lọc theo bữa, khẩu phần
  tăng theo kcal đốt), 15/15 test dinh dưỡng qua, analyze sạch. Chưa chạy trên máy.

### 5.28 Chống đẩy: tập đúng vẫn bị báo `tempo` và `sag` ở mọi rep (P01, 24/11, sửa sau khi đã đóng băng build)

Đây là lần sửa code sau khi build đã đóng băng (kế hoạch, nguyên tắc 3). Phải ghi rõ trong báo cáo.

- Hiện tượng (log `20261124T100014Z-P01`, điều kiện `ai`): app đếm đúng 10/10 nhưng 0 rep được chấm đúng.
  `tempo` có ở cả 10 rep, `sag` ở 8 rep. P01 tập đúng, nhất là 4 rep cuối, vẫn bị nhắc.
- Nguyên nhân 1, `tempo` ("Không thả rơi"): thời gian hạ người được tính từ lúc khuỷu gập khoảng 130° tới lúc
  vào trạng thái "đáy" ở khuỷu 115°. Như vậy chỉ đo khoảng 20° đầu của pha hạ. P01 xuống sâu tới khuỷu 44–56°, nên
  số đo luôn là 0,09–0,24 s, dưới mốc lỗi 0,3 s. Tính lại từ log, P01 thật sự hạ người mất 0,73–1,7 s mỗi rep,
  tức là đều đạt mốc "tốt" 0,6 s.
- Nguyên nhân 2, `sag` (võng hông / hông cao): code đo góc của đoạn hông–vai so với phương ngang của ảnh, tức độ
  nghiêng của thân so với sàn, không đo người có thẳng không. Người thẳng ở tư thế tay duỗi có vai cao hơn hông
  khoảng 15–20° (test có sẵn đo được 21,3° với một thân thẳng hoàn toàn), nên bị tính là "võng" (mốc 12°). Ở đáy, vai
  thấp hơn hông vài độ nên bị tính là "hông cao" (mốc 6°). Trong log, lỗi võng bắt đầu lúc đang đẩy lên gần đỉnh, lỗi
  hông cao bắt đầu đúng lúc ở đáy.
- Sửa:
  - `tempo_metric.dart`: thời gian hạ người tính tới lúc bắt đầu đẩy lên (chuyển sang `ascending`), không dừng ở
    mốc 115°. Mốc 0,3 s / 0,6 s giữ nguyên.
  - `push_up.dart`: `trunkDeviation` đổi thành độ gập của thân tại hông, bằng 180° trừ góc vai–hông–cổ chân,
    dương là hông thấp hơn đường vai–cổ chân (võng), âm là hông cao hơn (vểnh). Số đo này không phụ thuộc thân
    nghiêng bao nhiêu so với sàn. Cách tính lấy từ `_bodyLine`, trước đây chỉ in ra để gỡ lỗi.
  - `trunk_alignment_metric.dart`: ngưỡng mới cho số đo mới. Võng: nhắc nhẹ > 10°, lỗi > 15°, nguy hiểm > 25°.
    Vểnh: nhắc nhẹ > 12°, lỗi > 18°. Ngưỡng là ước lượng, chưa đo trên máy. Rep có thân gập > 30° vẫn bị chặn
    không tính như trước (`ACTIVE_BODY_LINE_MIN` 150°).
- Không đổi: mã lỗi vẫn là `sag` cho cả võng và vểnh. Khi vểnh, giọng vẫn phát `push_up/sag.mp3` ("siết bụng, giữ
  người thành một đường thẳng") vì chưa có file giọng cho vểnh (`missing-audio.md` dòng 83).
- Log: khoá `max_abs_trunk_deviation` và `descending_time` giữ tên nhưng đổi nghĩa từ build này (độ gập tại hông;
  thời gian hạ tới lúc đẩy lên). Không so trực tiếp với log chống đẩy trước 24/11 chiều.
- Hệ quả cho đợt đo: hiệp chống đẩy `ai` của P01 (`100014Z`) bị loại khỏi precision/recall chống đẩy. P01 tập lại
  chống đẩy ở cả `ai` và `control` bằng bản mới. Các bài khác của P01 (squat, cầu mông, plank) không bị ảnh hưởng
  vì code của chúng không đổi. Từ P01 trở đi, mọi người dùng bản mới.
- Test: 3 test mới trong `push_up_form_test.dart` (hông cao báo vểnh; thân thẳng nghiêng 15° không báo võng; thời
  gian hạ đo tới lúc đẩy lên, không báo `tempo`). Test võng đổi độ võng 25 thành 15 px cho khớp ngưỡng mới. Test
  `batch_a_review_probe_test.dart` trước đây khẳng định thân thẳng có `dev` 21,3°, nay là 0°. 845 test qua (14 bỏ
  qua), analyze không có lỗi mới, build APK profile thành công. Chưa thử trên máy. Chưa commit.

### 5.29 Sổ sự cố đợt đo: 3 buổi của P02 ghi nhầm mã P01 (24/11)

- Người điều phối quên đổi mã sau P01. Các buổi `20261124T101449Z` (squat), `101907Z` (cầu mông), `102133Z`
  (plank) là của P02 nhưng ghi `P01`, điều kiện `ai`, trên build cũ (trước 5.28).
- Đã sửa trên máy tính: đổi tên tệp và `participant_id`, `session_id` sang `P02`. Bản gốc chưa sửa được sao lưu ngoài
  repo. Bản trên điện thoại vẫn mang tên `P01` cho tới khi sửa nốt; kéo log lần sau sẽ chép lại 8 tệp tên `P01`
  này, phải xoá chúng khỏi `phone_logs`.
- P02 mã chẵn, theo kế hoạch phải tập `control` trước, nhưng đã tập `ai` trước. Ghi nhận lệch thứ tự này trong báo cáo.
- Bổ sung sau khi hỏi người điều phối: các buổi `102514Z`, `102528Z` (chống đẩy bản mới) và `102809Z` (squat 2 rep, để
  chạy 49 phút) cũng là của P02. Buổi `111748Z` (squat) đúng là của P01. Buổi mã `P010` (`122347Z`, squat) là của
  P04. Đã đổi tên và `participant_id` ở cả máy tính và điện thoại; bản gốc sao lưu ngoài repo.

### 5.30 Sổ sự cố đợt đo: tình trạng số liệu P01–P06 (24/11, đợt đo dừng ở P06)

- Danh sách người tập, vai trò và điều kiện nằm ngoài repo (`D:\VikaStudy\participants.csv`, có họ tên thật).
- Chỉ P04 có hiệp `control`. P04 tập xen kẽ `control`/`ai` theo từng bài và có P03 đứng hướng dẫn, chấm trong buổi,
  nên không phải đối chứng sạch (nghiêng về điều kiện "có HLV").
- P05: một người trong nhóm phát triển (P00) cùng tập trong một số hiệp mang mã P05. Chưa tách được hiệp nào của ai.
  Theo quyết định của chủ dự án (25/11), P05 vẫn được đưa vào bảng số liệu; báo cáo phải ghi rõ điều này.
- Làm sạch (25/11): giữ 39/70 hiệp. Loại hiệp 0 rep, hiệp để app chạy không (người ngoài khung > 50% thời gian), các
  lần tập lỗi của P01 trước lần cuối, và hiệp bỏ dở rồi mở lại (trừ plank). Hiệp chống đẩy cũ của P01 (`100014Z`) được
  giữ làm số liệu "trước khi sửa" (5.28), không gộp vào số liệu chống đẩy sau sửa. App đếm đúng (±1 rep) 36/39 hiệp;
  3 hiệp đếm sai (McGill, gập bụng của P03; cầu mông `control` của P04) được giữ vì là lỗi của app.
- Điều kiện: mọi người đặt máy ở vị trí chuẩn theo thẻ đặt máy trong app. Đặt máy ở góc khác thì app báo lỗi vị trí và
  không chấm, nên không có hiệp nào được chấm ở góc khác. Ánh sáng: ngược sáng (P01, P02), thiếu sáng (P05), đủ sáng
  (P03, P04, P06). Quần áo dày: P02, P05.
- Mỗi người chỉ có 1 lượt plank (thoát sau hiệp 1 trong 3). Chưa ai có hiệp lỗi cố ý (`P0xS`). App không hỏi mức hài
  lòng khi thoát giữa chừng, nên ô `satisfaction` trống ở mọi buổi.
- 26/11: theo quyết định của chủ dự án, hiệp cầu mông đầu tiên của P01 (`095416Z`, 10 rep, app chấm đúng 4) được
  đưa trở lại vì là lần tập hợp lệ. Số hiệp sạch thành 40/70, app đếm đúng (±1 rep) 37/40.
- Rà soát kết quả (26/11): bỏ người chấm C2; hai chuyên gia C1, C3 xem video máy B và rà soát kết quả app in sẵn trong
  phiếu, chủ dự án ghi phiếu theo nhận xét của họ, họ đọc lại và ký. Không phải chấm mù. Trên 306 rep (không tính
  chống đẩy trước bản sửa): C1 đồng ý 85,3%, C3 87,3%; kappa C1–C3 0,98; kappa app với kết luận chung 0,87; recall
  99,5%; precision 81,2% (C1) / 83,7% (C3), không tính `speed_control` của cầu mông thì 94,3% / 97,7%.
- Điểm không đồng ý: `speed_control` cầu mông ở P03, P04, P06 (chuyên gia: chỉ cần lên và giữ, hạ có kiểm soát nhưng
  không cần chậm như ngưỡng hiện tại; không áp dụng cho P01, P02 theo chủ dự án); gập bụng P03 (`rom`, C1 không đồng
  ý vì người cơ bụng to khó cuộn tròn, C3 đồng ý); chống đẩy tường P03 rep 5, 6; squat `control` P04 rep 2 (app nhạy);
  squat P05 rep 1 (app bỏ sót `tempo`). Không chuyên gia nào ghi rep bị bỏ sót hay rep "không tính".
- Chuyên gia đồng ý với cả hiệp chống đẩy trước bản sửa của P01 (sag 8 rep, tempo 10 rep), trái với phân tích ở 5.28.
  Hiệp này vẫn để riêng, không tính vào các chỉ số trên. Kết quả lưu ở `D:\VikaStudy\cham_diem\ket_qua_ra_soat.json`.

### 5.31 Plank thấp: một hiệp đòi nhiều lượt liền nhau; sai tư thế giữa lượt thì đồng hồ về 0 (26/11, sửa sau khi đã đóng băng build)

Chủ dự án báo: một hiệp bắt giữ nhiều lượt liền nhau (thấy 3), chỉ nghỉ 5 s ngay trong màn tập thay vì ra màn
nghỉ; sai tư thế giữa lượt thì đồng hồ đếm lại từ 0.

- **Một hiệp nhiều lượt**, hai nguyên nhân:
  - `exercise_experience_screen.dart`, nhánh `plank`: với bài giữ, `target` là số giây, nhưng lại được truyền làm
    số lượt. Danh mục sau 5.27 (3 hiệp × 1 lượt × 20 s) cho ra `Plank(maxRep: 20)`, tức mỗi hiệp đòi 20 lượt
    20 s. Trước 5.27 danh mục ghi 1 hiệp × 3 lượt nên một hiệp là 3 lượt. Khớp với 5.30: người tập dừng sau lượt
    đầu của hiệp 1.
  - Màn nghỉ: chọn "Nhẹ" thì hiệp sau +2 rep, "Nặng" thì −1 rep, áp cả cho plank. Hiệp 1 có 1 lượt, chọn "Nhẹ" thì
    hiệp 2 có 3 lượt liền nhau. Buổi trước đánh giá "nhẹ" thì ngay hiệp 1 đã thêm 1 lượt.
- **Đồng hồ về 0**: trong `plank.dart`, thân lệch, gối co, bỏ cẳng tay, mất khung hình hoặc mất điểm khớp giữa lượt
  (khi đã giữ chưa tới thời gian lượt − 3 s) đều đưa về "chuẩn bị", xóa thời gian đã giữ và xóa lỗi của lượt đó.
- Sửa:
  - Số lượt mỗi hiệp lấy từ `reps` (plank = 1), thời gian lượt lấy từ `seconds`. Danh mục cũ chỉ có `reps` vẫn chạy
    như trước.
  - Plank không đổi số lượt theo câu trả lời độ khó, màn nghỉ không còn hiện "Set sau tăng 2 reps" cho plank.
    "Nặng" vẫn +15 s nghỉ.
  - Thêm pha `paused` ("Tạm dừng"): sai tư thế thì đồng hồ dừng ở số giây đã giữ và giọng nhắc lỗi; về đúng tư thế
    2 khung hình liên tiếp thì đếm tiếp. Thời gian sai tư thế không cộng vào `total_seconds` và `hold_time`. Lỗi
    xảy ra trước lúc dừng vẫn thuộc lượt đó. Lượt dừng khi đã giữ ≥ thời gian lượt − 3 s vẫn tính xong (giữ quy
    tắc 5.25). Giọng đếm giây không đọc lại số trong lúc dừng.
- Số liệu: các hiệp plank P01–P06 chạy cách đếm cũ, không gộp chung với số liệu plank sau lần sửa này.
- Test: dừng rồi đếm tiếp (8,0 s → dừng 4 s → đủ 15 s ở đúng 15,0 s giữ thật), thời gian sai tư thế không tính,
  danh mục 3 × 1 × 20 s ra 1 lượt 20 s mỗi hiệp, kế hoạch 25 s ra 1 lượt 25 s. Sửa 5 test cũ đang khẳng định
  hành vi về 0. 874 Flutter test qua (14 bỏ qua), analyze sạch các file đã sửa. Chưa thử trên máy, chưa build APK.

## 6. Việc còn mở

- Jumping Jack: 24% thời gian tập bị chặn, nhiều nhất là "quay mặt vào camera" (29 lần, 5,2 s). Chưa
  rõ có nhảy nào bị bỏ sót không: 6 lần lên pha "mở" đều được đếm.
- Mountain Climber: lỗi `rom` (đá chân thẳng, gối 124–142°) được ghi nhưng không có giọng nhắc. 3 rep
  này cách nhau 0,4–0,5 s, nghi giọng nhắc bị nhường cho giọng đếm số.
- Push-up: test lại khi người test tập được đúng bài.

- Squat: lỗi tempo đã sửa (5.12), test trên máy 22/11: 0/8 rep báo tempo, thời gian xuống 0,69–1,08 s.
- Squat: lỗi `sync` đã đổi cách đo (5.13). Cần test trên máy để chỉnh ngưỡng 6° / 10° theo
  `ascent_lean_rise`.
- Squat: rep vẫn được đếm khi người đứng chéo camera (app chỉ chặn khi quay mặt thẳng vào camera; lúc
  chéo thì góc thân ghi 0, không kiểm tra thân) và khi điểm khớp sai rõ (gối 10,6°, 20,7°). Liên quan Yêu
  cầu 2.
- Glute Bridge: đếm nửa rep đã sửa (5.14), cần test trên máy.
- Wall Push-up: đếm đôi đã sửa (5.15), cần test trên máy. Ngưỡng độ sâu 132° vẫn dễ: rep gập tới 129°
  vẫn tính đúng form.
- Squat: màn hình hiện "Cố giữ ngực mở" ở đáy mọi rep vì thân đổ trước 35–39° vượt mức nhắc 30°, dù vẫn
  trong khoảng "tốt" 15–60° của chính metric đó. Không tính lỗi, chỉ là chữ nhắc.
- Lunge: rep nông chỉ bị "không tính", không có giọng nhắc. File `lunge/depth.mp3` ("hạ gối sau xuống
  gần sàn hơn") hợp để nhắc đúng lúc này.
- Lunge: 20 lần bị chặn "thiếu sáng" (4,2 s) trong lúc tập, vì bài đòi cả 12 điểm hai bên chân đủ tin
  cậy, kể cả chân phía xa bị che.
- Wall Push-up: dải đếm rep 132–138° quá hẹp (xem 5.6). Phần đếm đôi đã xử lý ở 5.15; thời gian đẩy
  lên vẫn chỉ đo tới lúc khuỷu qua ngưỡng xong rep.
- Bird Dog: lượt bị loại không có giọng nói giải thích; chưa có file âm thanh cho "đổi bên", "tay chân
  đối nhau", "giữ 1,5 s".
- Lunge, Jump Squat, Wall Push-up, Bird Dog, Plank: test lại sau khi cài bản mới, đọc sự kiện `phase`.
- Jump Squat: rep 1 bị báo `landing_stiff` và `takeoff_depth` (lấy đà 135°), chưa rõ đúng hay sai.
- Camera: đo lại thời gian mở trên máy.
- Step-up, Giãn cổ nghiêng, Chống đẩy xoay người (5.16): chưa test trên máy, mọi ngưỡng chưa đo.
  Chưa có video mẫu, chưa có file giọng (12 câu, `missing-audio.md` dòng 184–195), chưa khai báo thư
  mục giọng trong `pubspec.yaml`.
