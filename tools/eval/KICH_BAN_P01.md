# Kịch bản buổi đo P01 (nhóm A, 24/11/2026)

P01 là người tập độc lập đầu tiên và tập **đủ 21 bài**: 4 bài chính theo nhóm A (`KE_HOACH_THU_SO_LIEU.md` mục 5),
rồi 17 bài còn lại theo cách của nhóm B (mục 7 dưới đây). Log của P01 được đưa vào bảng precision/recall, nên mọi
nguyên tắc ở mục 0 của kế hoạch đều áp dụng: build đã đóng băng, người điều phối không nhắc lỗi, HLV không có mặt
lúc tập.

Thời gian: khoảng **1 giờ 50 phút** (4 bài chính 55 phút, 17 bài còn lại 55 phút). Buổi dài gấp đôi khung 1 giờ của
kế hoạch, nên xếp P01 vào 2 khung liền nhau và nghỉ 10 phút giữa hai phần. Mỗi bài trong 17 bài có thêm 1 người
(P01), ngoài 4 người nhóm B.

## 0. P01 là ai

- Một người **ngoài nhóm**, chưa từng tập thử app và chưa góp dữ liệu chỉnh ngưỡng. Không cần là người tập thể
  thao. Đề yêu cầu "người và điều kiện mới, nhiều vóc dáng", và hạn ngạch tính trên **cả nhóm A (P01–P10)**:
  ≥ 3 nữ, ≥ 3 nam, ≥ 2 người BMI ≥ 25, ≥ 2 người BMI < 20, cao nhất hơn thấp nhất ≥ 20 cm, ≥ 3 người mới tập (dưới
  1 buổi/tuần). Một người không cần đáp ứng tất cả. Khi xếp lịch thì chọn người sao cho cả nhóm đủ hạn ngạch.
- Góc máy, ánh sáng, quần áo, thiết bị cũng chia đều cho cả nhóm, không ai phải thử hết. Mỗi người chỉ thử
  **2 mức** trong khối thay đổi điều kiện (mục 6). Của P01 là:
  - **G2**: máy đặt chéo 45°;
  - **A3**: ngược sáng.
- **Quần áo:** P01 mặc đồ tập bình thường của mình suốt buổi. Chỉ ghi lại đang mặc gì (bó/rộng, màu, nền phía sau).
  Các mức đổi quần áo do người khác làm: Q2 áo quần rộng (P02, P06, P10), Q3 đồ tối trên nền tối (P03, P04, P07, P08).
- Mã lẻ nên P01 tập điều kiện `ai` **trước**, `control` sau.

## 1. Chuẩn bị trước khi P01 đến (người điều phối, 10 phút)

1. Máy A đã cài **build đóng băng**. Ghi số build và commit hash vào sổ (nếu đây là người đầu tiên của ngày).
2. Hồ sơ → Cài đặt nghiên cứu: mã `P01`, điều kiện "Có phản hồi AI (ai)". Dòng dưới phải hiện "Mã đang ghi vào
   tệp: P01".
3. Dán băng dính đánh dấu vạch chuẩn: máy A nằm ngang, cao 60–70 cm, cách chỗ tập 3 m, nhìn nghiêng.
4. Máy B (điện thoại thường, không cài Vika): nằm ngang, cạnh máy A cùng phía, 1080p, bật tiếng. Không để màn hình
   máy A lọt vào khung. Quay liên tục.
5. Chuẩn bị: thảm, app đo sáng, cân, thước, phiếu đồng ý, phiếu sàng lọc, phiếu thứ tự lỗi cố ý của P01 (mục 5),
   phiếu 3 câu hỏi giấy.
6. Cắm sạc máy A giữa hai người, tháo ốp, đặt quạt.

## 2. Mở đầu (10 phút)

1. Ký phiếu đồng ý (3 ô riêng: tập, dữ liệu cá nhân và sức khoẻ, hình ảnh). Sàng lọc kiểu PAR-Q; có bệnh tim, đau
   cấp, chấn thương đang điều trị hoặc mang thai thì không tập.
2. Đo chiều cao, cân nặng, tính BMI. Hỏi mức tập (số buổi/tuần). Ghi quần áo đang mặc. Đo lux ở chỗ tập. Ghi vào
   `participants.csv`.
3. Khởi động 5 phút.
4. **Thử tự đặt máy (yêu cầu 2).** Đưa máy A cho P01, để P01 tự đặt máy chỉ theo hướng dẫn trong app, không ai
   giúp, không chỉ vạch dán. Ghi: thời gian từ lúc cầm máy tới lúc xong, khoảng cách, độ cao, góc, app có thấy đủ
   người không. Xong thì người điều phối đặt lại máy về vạch chuẩn.

## 3. Cách tập một hiệp (nói với P01 trước khi bắt đầu)

- Vào tư thế bắt đầu, giữ yên 3 giây, chờ **một tiếng bíp** rồi mới tập.
- Tập theo cách mình vẫn tập. Không cần cố làm đúng hay cố làm sai (trừ khối lỗi cố ý ở mục 5).
- Tự đếm, không nhìn màn hình. Tập đủ số rep thì dừng.
- Đau hoặc chóng mặt thì dừng ngay.

Người điều phối:
- **Không nhắc lỗi**, không sửa tư thế, không giải thích lời nhắc của app.
- Tập đủ mà app chưa sang màn nghỉ: bấm quay lại, chọn Thoát. App sang màn nghỉ khi chưa tập đủ: dừng, Thoát.
- Ghi 1 dòng mỗi hiệp: app đếm được mấy, có kẹt ở lời nhắc đặt máy không, sự cố gì.

Số rep (lấy theo `assets/data/exercise_catalog.json`, giống kịch bản P00):

| Bài | Số rep một hiệp |
|---|---|
| Squat | 8 |
| Chống đẩy | 10 |
| Cầu mông | 10 |
| Plank thấp | 3 hiệp × 1 lượt 20 s, nghỉ 20 s giữa hiệp (app đọc 1–7, "được một nửa", rồi 5–1) |

Plank: giữ tới khi app đếm xong lượt, không tự dừng.

## 4. Hai điều kiện tự nhiên (khoảng 20 phút)

### Khối 1: điều kiện `ai`

Tập lần lượt Squat, Chống đẩy, Cầu mông, Plank thấp. Mỗi bài 1 hiệp, tập tự nhiên. Hết khối thì trả lời câu hỏi hài
lòng trong app.

### Nghỉ 5 phút, đổi điều kiện

Hồ sơ → Cài đặt nghiên cứu → "Đối chứng — không phản hồi (control)". Mã vẫn `P01`. Trước khi tập cho P01 xem video
hướng dẫn của từng bài (đây chính là điều kiện đối chứng).

### Khối 2: điều kiện `control`

Cùng 4 bài, cùng thứ tự, cùng số rep. App không hiện số đếm, không hiện khung xương, không nhắc lỗi, nhưng vẫn phải
có tiếng bíp lúc bắt đầu. Không có bíp thì ghi lại. Hết khối thì trả lời câu hỏi hài lòng trong app, rồi 3 câu giấy:
hữu ích, tin tưởng, phiền; và "muốn tập có AI hay không".

## 5. Lỗi cố ý (khoảng 10 phút, mã `P01S`, điều kiện `control`)

Đổi mã thành `P01S`, vẫn `control`. Mỗi bài 1 hiệp theo phiếu thứ tự in sẵn của P01: khoảng 1/3 rep đúng, còn lại
chia đều các lỗi, thứ tự xáo trộn. Người điều phối đọc to rep kế tiếp làm gì; P01 không cầm phiếu trong khung hình.
Chỉ diễn lỗi an toàn. Lỗi vừa đủ rõ, không làm động tác gây đau.

Lỗi dự kiến (HLV chốt ở buổi hiệu chuẩn, tối đa 3 lỗi mỗi bài; HLV đổi thì theo HLV):

| Bài | Số rep | Lỗi diễn |
|---|---|---|
| Squat | 8 | `depth` xuống nông, `trunk` đổ người trước |
| Chống đẩy | 10 | `depth` gập khuỷu ít, `sag` võng hông |
| Cầu mông | 10 | `hip_extension` nâng hông thấp, `speed_control` thả hông rơi nhanh |
| Plank thấp | 5 lượt | đúng, võng hông, vểnh mông, cúi đầu (`Neck`), chùng gối (`Knees`), thứ tự theo phiếu |

Plank giờ là 3 hiệp × 1 lượt, nên 5 lượt = tập hết 3 hiệp, Thoát, mở lại bài và tập thêm 2 hiệp. Mỗi lượt giữ lỗi
**suốt lượt**. Võng quá nhiều thì app coi là bỏ tư thế và tính lại lượt: võng ít lại.

Ví dụ phiếu squat (tự xáo khác cho mỗi người): đúng, `depth`, `trunk`, đúng, `trunk`, `depth`, đúng, `depth`.

Xong khối thì đổi mã về `P01`.

## 6. Khối thay đổi điều kiện (khoảng 10 phút, mã `P01`, điều kiện `ai`)

Mỗi mức gồm **Plank thấp + Squat**, tập tự nhiên. Mỗi lần chỉ đổi đúng 1 yếu tố, xong thì trả về chuẩn.

| Lần | Mức | Cách làm |
|---|---|---|
| 1 | G2 chéo 45° | Giữ khoảng cách 3 m và độ cao 60–70 cm, xoay vị trí máy A quanh người tập để máy nhìn chéo 45° giữa mặt trước và mặt bên. Máy B giữ nguyên |
| 2 | A3 ngược sáng | Máy A về vạch chuẩn. Người tập đứng (nằm) giữa máy và nguồn sáng: cửa sổ hoặc đèn sáng ở phía sau lưng người, chiếu thẳng về máy. Đo lux ở chỗ tập, ghi lại |
| 3 | Máy D2 (chỉ khi mượn được) | Máy D2 cùng build, đặt ở vạch chuẩn, đủ sáng. Đặt mã `P01` trên máy D2 |

Trong khối này **không bấm "Bỏ qua cảnh báo"**. App có ba cách phản ứng:
- chấm và đếm bình thường;
- từ chối chấm (lời nhắc quay ngang, thiếu sáng, "Chưa đủ căn cứ để chấm"). Đây cũng là phản ứng đúng;
- chấm sai mà không báo gì (cái cần bắt).

Nếu app kẹt ở lời nhắc quá 30 giây thì P01 vẫn tập đủ số rep, rồi Thoát và ghi "kẹt lời nhắc …, … giây".

Ghi vào `session_conditions.csv` một dòng cho mỗi hiệp: góc, độ cao, lux, quần áo, địa điểm, thiết bị.

## 7. 17 bài còn lại (khoảng 55 phút)

Nghỉ 10 phút trước phần này, cho uống nước. Cách tập giống nhóm B (kế hoạch mục 5): mỗi bài 2 hiệp liền nhau.

1. **Hiệp tự nhiên:** mã `P01`, điều kiện `ai`. Tập theo cách mình vẫn tập.
2. **Hiệp lỗi cố ý:** mã `P01S`, điều kiện `control`. Khoảng 1/3 số rep đúng, còn lại chia đều các lỗi ở cột "Lỗi
   cố ý", thứ tự theo phiếu in sẵn, người điều phối đọc to. Bài giữ: diễn lỗi vào đoạn giây ghi trong bảng.

Đổi mã và điều kiện mỗi bài thì mất thời gian. Cách nhanh hơn: tập hết các hiệp tự nhiên của một nhóm tư thế (ví dụ
5 bài đứng) ở `P01`/`ai`, rồi đổi sang `P01S`/`control` và tập các hiệp lỗi cố ý của nhóm đó.

Số rep lấy theo `assets/data/exercise_catalog.json`, giống kịch bản P00. Lỗi dự kiến chờ HLV chốt (tối đa 3 lỗi mỗi bài).

| # | Bài | Số rep | Lỗi cố ý |
|---|---|---|---|
| | **Đứng** | | |
| 1 | Lunge | 10 | `trunk` đổ người về trước |
| 2 | Squat bật nhảy | 12 | `takeoff_depth` nhún nông rồi bật, `landing_stiff` tiếp đất gối gần thẳng |
| 3 | Jumping Jack | 20 | `arms` tay không qua đầu, `legs` chân mở hẹp |
| 4 | Chống đẩy tường | 10 | `body_line` gập ở hông, `head` đưa đầu ra trước |
| | **Chống tay** | | |
| 5 | Plank nghiêng | 1 lượt × 15 s | Giây 8–12 chùng hông xuống (`amplitude`), rồi thẳng lại tới hết lượt |
| 6 | Leo núi | 16 (8 mỗi chân) | `rom` co gối ít, `trunk_bounce` nảy hông lên xuống |
| 7 | Dip cơ tay sau (chống mép ghế chắc 30–45 cm) | 10 | `rom` gập khuỷu ít |
| | **Nằm ngửa** | | |
| 8 | Gập bụng | 10 | `rom` lên nửa chừng, `stability` nhấc chân khỏi sàn |
| 9 | Nâng chân | 10 | `knee` co gối, `rom` nâng chân thấp |
| 10 | Gập bụng chữ V | 6 | `knee` co gối, `rom` gập nông |
| 11 | Gập bụng McGill | 10 | `neck_pull` gập cằm vào ngực, `trunk_high` nâng thân quá cao. Mỗi rep hạ xuống nằm yên khoảng 1 giây |
| 12 | Dead Bug | 8 (4 mỗi bên) | `opposite_side` duỗi tay chân cùng bên, `alternate` lặp lại đúng bên lần trước |
| | **Bốn điểm, nằm sấp** | | |
| 13 | Bird Dog | 8 (4 mỗi bên) | `opposite_side` duỗi tay chân cùng bên, `head` cúi đầu thấp |
| 14 | Superman | 10 | `elevation_arm` tay nâng thấp, `elevation_leg` chân nâng thấp |
| 15 | Tư thế nhân sư | 1 lượt × 30 s | Giây 15–20 rụt vai lên tai (`shrug`), rồi thả vai tới hết lượt |
| | **Ngồi** | | |
| 16 | Tư thế ngồi gập người | 1 lượt × 30 s | Giây 15–20 co gối (`knee`), rồi duỗi lại tới hết lượt |
| 17 | Tư thế con bướm | 1 lượt × 30 s | Giây 15–20 gù lưng (`posture`), rồi ngồi thẳng tới hết lượt. Bài chưa chấm form, không nhắc lỗi là bình thường |

Chỗ đã biết app còn yếu (`docs/field-test-log.md` 5.26, 5.27): dead bug bắt lỗi cùng bên / không đổi bên dựa vào tay chân
phía xa camera nên không tin được; dip tay sau chưa chấm `hip_thrust`. Vẫn tập và vẫn để HLV chấm, không bỏ bài.

P01 mệt hoặc đau ở bài nào thì bỏ bài đó, ghi lý do. Không ép tập đủ.

## 8. Kết thúc (5 phút)

1. Giãn cơ.
2. Xuất log: cắm cáp, chạy `.\tools\eval\pull_phone_logs.ps1`, hoặc Cài đặt nghiên cứu → "Chia sẻ tất cả tệp nhật
   ký". Kiểm tra có log mã `P01` và `P01S`.
3. Chép video máy B ra `D:\VikaStudy\P01\`, không bỏ vào repo.
4. Ghi sổ sự cố: máy nóng, FPS tụt, kẹt lời nhắc, rep app đếm lệch.
5. Cắt clip luôn (`clips.py suggest`, `cut`) để HLV chấm được từ chiều.
6. Đổi mã sang `P02` trước khi người sau đến. P02 mã chẵn nên tập `control` trước.

## 9. Kiểm nhanh sau buổi

- 4 bài chính: 8 hiệp tự nhiên (4 bài × 2 điều kiện), 4 hiệp lỗi cố ý (plank thành 2 lần mở bài), 4 hiệp thay đổi
  điều kiện (6 nếu có máy D2).
- 17 bài còn lại: 17 hiệp `P01`/`ai` và 17 hiệp `P01S`/`control`, trừ bài nào bỏ có ghi lý do.
- Mọi hiệp đều có tiếng bíp, kể cả `control`.
- `participants.csv` và `session_conditions.csv` đã có dòng của P01.
