# Kịch bản tập P00 (tối 23/11/2026)

`P00` là mã của nhóm tự tập thử. Log `P00` không bao giờ vào bảng precision/recall. Nó chỉ dùng để kiểm tra
app trước khi mời người mới (`KE_HOACH_THU_SO_LIEU.md` mục 4.3).

Mục tiêu tối nay:
- cả 21 bài qua `p00_gate.py`;
- 4 bài chính có thêm 1 hiệp đối chứng (`control`);
- thử 2 tính năng mới: "Bỏ qua cảnh báo" và "Báo sai".

Thời gian: khoảng 1 tiếng 45 phút.

## 1. Chuẩn bị (15 phút)

1. **Cài bản mới lên điện thoại Android.** Cắm cáp, mở PowerShell ở `D:\Vinafit-mobile`, chạy:
   ```powershell
   .\.fvm\flutter_sdk\bin\flutter.bat run --profile
   ```
   Chờ app mở trên máy, rồi bấm `q` trong PowerShell. App vẫn nằm lại trên máy.
   - Bản `--profile` chạy nhanh như bản thật. Bản debug chậm hơn, FPS thấp hơn.
   - Bản này cài đè lên bản `.dev` cũ và giữ nguyên dữ liệu.
2. **Đặt mã.** Trong app vào tab Hồ sơ, chọn Cài đặt nghiên cứu.
   - Mã người tham gia: gõ `P00`. Dòng dưới phải hiện "Mã đang ghi vào tệp: P00".
   - Điều kiện thử nghiệm: chọn "Có phản hồi AI (ai)".
3. **Đặt máy A** (máy cài Vika):
   - nằm ngang, cao 60–70 cm, cách chỗ tập khoảng 3 m;
   - thấy cả người từ đầu tới chân, kể cả lúc nằm;
   - đèn chiếu vào người, không đứng ngược cửa sổ;
   - bật âm lượng to.
4. **Dụng cụ:**
   - thảm;
   - một mảng tường lọt khung máy ở 3 m, cho bài chống đẩy tường.
5. **Máy B (nên có).** Một điện thoại khác quay video liên tục cả buổi.
   - Cách đặt: nằm ngang, đặt cạnh máy A và cùng phía, thấy cả người.
   - Bật tiếng để thu được tiếng bíp.
   - Không để màn hình máy A lọt vào khung.
   - Video dùng cho buổi hiệu chuẩn HLV ngày mai và để chạy thử `clips.py`.
   - Lỡ phải dừng quay giữa chừng cũng không sao, mỗi video chỉ cần nghe ra 1 tiếng bíp.
   - Chép video ra ngoài repo, ví dụ `D:\VikaStudy\P00\`, đừng bỏ vào `D:\Vinafit-mobile`.
6. **Giấy bút**, hoặc in bảng ở mục 3, để ghi cột "Ghi".

## 2. Cách tập một hiệp (giống nhau cho mọi bài)

1. Vào tab Thư viện, chọn bài, bấm bắt đầu. Lần đầu mở một bài, app có thể chiếu video hướng dẫn: xem hoặc bỏ
   qua đều được.
2. Màn đầu bài ghi số REP/HIỆP hoặc GIÂY/HIỆP. Bảng ở mục 3 đã ghi sẵn con số đó cho từng bài.
3. Vào tư thế bắt đầu, giữ yên 3 giây. App kêu **một tiếng bíp**: từ lúc này app bắt đầu đếm. Tiếng bíp cũng là
   mốc để khớp video máy B với log.
4. Tập đúng số rep trong bảng.
   - **Tự đếm, đừng nhìn số trên màn hình.**
   - Các rep đầu làm đúng. Các rep sau cố ý làm lỗi như cột "Lỗi cố ý".
   - Làm lỗi vừa đủ rõ, không làm động tác nào gây đau.
5. Kết thúc hiệp:
   - App đếm đủ thì tự sang màn nghỉ. Bấm nút quay lại của điện thoại (hoặc vuốt quay lại) để ra khỏi bài.
     Không tập hiệp 2.
   - Bạn đã tập đủ mà app chưa sang màn nghỉ (app đếm thiếu): bấm quay lại, app hỏi "Thoát buổi tập?", chọn
     Thoát. Câu "Tiến độ hiệp này sẽ không được lưu" là nói lịch sử tập; tệp nhật ký nghiên cứu vẫn được lưu.
   - App sang màn nghỉ khi bạn chưa tập đủ (app đếm thừa): dừng, ra khỏi bài, ghi lại.
6. Ghi ngay 1 dòng vào cột "Ghi":
   - App đếm được mấy?
   - Rep lỗi cố ý có bị nhắc không, và nhắc **đúng tên lỗi** không?
   - Có nghe thấy giọng nói không?
   - Rep đúng có bị nhắc oan không?
   - Có bị kẹt ở lời nhắc đặt máy ("quay ngang", "vào khung", "thiếu sáng") không?
   - Rep lỗi cố ý mà app không đếm thì vẫn tính vào số bạn đã tập, và ghi "rep N không đếm".

Hai lưu ý:
- **Bài giữ:** app tính 1 lần khi bạn giữ đủ thời gian. Trong lúc làm lỗi, đồng hồ có thể dừng, hoặc lượt bị tính
  lại từ đầu. Cứ sửa lại tư thế cho tới khi app tính xong lượt, rồi ghi lại chuyện đó.
- **Bài tính mỗi bên 1 lần:** dead bug, bird dog, leo núi.

## 3. 21 bài, điều kiện `ai`

Tập theo thứ tự các nhóm dưới đây để ít phải đổi tư thế. Nghỉ giữa các bài tuỳ sức. Số rep là số app đặt cho một
hiệp (`assets/data/exercise_catalog.json`); `p00_gate.py` so với đúng số này.

### Đứng

| # | Bài | Số rep | Rep đúng | Lỗi cố ý | Ghi |
|---|---|---|---|---|---|
| 1 | Squat | 8 | 1–4 | 5–6 xuống nông, đùi chưa ngang (`depth`). 7–8 đổ người về trước (`trunk`) | |
| 2 | Lunge | 10 | 1–5 | 6–10 đổ người về trước (`trunk`) | |
| 3 | Squat bật nhảy | 12 | 1–6 | 7–9 nhún nông rồi bật (`takeoff_depth`). 10–12 bật thấp, tiếp đất gối gần thẳng (`landing_stiff`) | |
| 4 | Jumping Jack | 20 | 1–10 | 11–15 tay không đưa qua đầu (`arms`). 16–20 chân mở hẹp (`legs`) | |
| 5 | Chống đẩy tường | 10 | 1–5 | 6–8 gập ở hông (`body_line`). 9–10 đưa đầu ra trước (`head`) | |

### Chống tay

| # | Bài | Số rep | Rep đúng | Lỗi cố ý | Ghi |
|---|---|---|---|---|---|
| 6 | Chống đẩy | 10 | 1–5 | 6–7 xuống nông (`depth`). 8–10 võng hông (`sag`) | |
| 7 | Plank thấp | 3 hiệp × 20 s (mỗi hiệp 1 lượt giữ, nghỉ 20 s giữa hiệp) | Hiệp 1 | Hiệp 2 võng hông vừa phải suốt lượt. Hiệp 3 vểnh mông cao vừa phải suốt lượt. Cả hai đều là mã `Back`. App đọc 1–7, "được một nửa" ở giây 10, rồi 5–1 | Giữ tới khi app đếm xong, đừng tự đếm |
| 8 | Plank nghiêng | 1 lượt × 15 s | Giây 0–8 | Giây 8–12 chùng hông xuống (`amplitude`), rồi thẳng lại tới hết lượt | |
| 9 | Leo núi | 16 (8 mỗi chân) | 1–8 | 9–12 co gối ít (`rom`). 13–16 nảy hông lên xuống (`trunk_bounce`) | |
| 10 | Dip cơ tay sau (tay chống mép ghế chắc hoặc mép giường; trên sàn app không bắt được) | 10 | 1–5, khuỷu gập dưới 120° | 6–8 gập khuỷu ít (`rom`). 9–10 đẩy hông lên xuống thay vì gập khuỷu (`hip_thrust`: app chưa chấm lỗi này) | |

Plank là bài quan trọng nhất (code còn ghi "verify sign mapping"). Nghe kỹ lời nhắc:
- hiệp 2 phải nói về hông bị **võng thấp**;
- hiệp 3 phải nói về mông bị **nhô cao**.

Nếu app nói ngược thì app đảo dấu: ghi lại. Võng quá nhiều thì app coi là bỏ tư thế plank: nó nói "Giữ thân người
thẳng như plank" và tính lại lượt từ đầu. Gặp vậy thì võng ít lại.

### Nằm ngửa

| # | Bài | Số rep | Rep đúng | Lỗi cố ý | Ghi |
|---|---|---|---|---|---|
| 11 | Cầu mông | 10 | 1–5 | 6–7 nâng hông thấp (`hip_extension`). 8–10 thả hông rơi nhanh xuống (`speed_control`) | |
| 12 | Gập bụng | 10 | 1–5 | 6–8 lên nửa chừng (`rom`). 9–10 nhấc chân khỏi sàn (`stability`) | |
| 13 | Nâng chân | 10 | 1–5 | 6–8 co gối (`knee`). 9–10 nâng chân thấp (`rom`) | |
| 14 | Gập bụng chữ V | 6 | 1–3 | 4–5 co gối (`knee`). 6 gập nông, tay chưa gần chân (`rom`) | |
| 15 | Gập bụng McGill | 10 | 1–5 | 6–8 gập cằm vào ngực (`neck_pull`). 9–10 nâng thân quá cao (`trunk_high`) | Nằm ngửa, 1 chân co 1 chân duỗi, 2 tay lót dưới thắt lưng; nhấc đầu và vai lên vài cm, giữ 1 nhịp, hạ xuống và nằm yên khoảng 1 giây trước rep sau |
| 16 | Dead Bug | 8 (4 mỗi bên) | 1–4, xen kẽ bên | 5–6 duỗi tay chân cùng một bên (`opposite_side`). 7–8 lặp lại đúng bên của lần trước (`alternate`) | |

### Bốn điểm, nằm sấp

| # | Bài | Số rep | Rep đúng | Lỗi cố ý | Ghi |
|---|---|---|---|---|---|
| 17 | Bird Dog | 8 (4 mỗi bên) | 1–4, xen kẽ bên | 5–6 duỗi tay chân cùng một bên (`opposite_side`). 7–8 cúi đầu thấp (`head`) | |
| 18 | Superman | 10 | 1–5 | 6–8 tay nâng thấp (`elevation_arm`). 9–10 chân nâng thấp (`elevation_leg`) | |
| 19 | Tư thế nhân sư | 1 lượt × 30 s | Giây 0–15 | Giây 15–20 rụt vai lên tai (`shrug`), rồi thả vai tới hết lượt | |

### Ngồi

| # | Bài | Số rep | Rep đúng | Lỗi cố ý | Ghi |
|---|---|---|---|---|---|
| 20 | Tư thế ngồi gập người | 1 lượt × 30 s | Giây 0–15 | Giây 15–20 co gối (`knee`), rồi duỗi lại tới hết lượt | |
| 21 | Tư thế con bướm | 1 lượt × 30 s | Giây 0–15 | Giây 15–20 gù lưng (`posture`), rồi ngồi thẳng tới hết lượt | Catalog ghi bài này chưa chấm form, nên không nhắc lỗi cũng là bình thường |

## 4. Bốn bài chính, điều kiện `control` (15 phút)

1. Vào Hồ sơ, Cài đặt nghiên cứu, chọn "Đối chứng — không phản hồi (control)". Mã vẫn là `P00`.
2. Tập lại Squat, Chống đẩy, Cầu mông, Plank thấp, giống hệt bảng ở mục 3: cùng số rep, cùng lỗi cố ý.
3. Ở `control`, app không hiện số đếm, không hiện khung xương, không nhắc lỗi.
   - Lúc bắt đầu vẫn phải có tiếng bíp. Không nghe thấy tiếng bíp thì ghi lại.
   - Tự đếm. Tập đủ rồi mà app chưa tự sang màn nghỉ thì Thoát.
4. Xong 4 bài thì chọn lại "Có phản hồi AI (ai)".

## 5. Thử 2 tính năng mới (10 phút, mã riêng)

Đổi mã người tham gia thành `P00T` để các hiệp này không lẫn vào cổng `P00`, điều kiện `ai`. Bạn đứng cách máy 3 m,
nên tốt nhất có một người đứng cạnh máy để bấm nút.

**Bỏ qua cảnh báo:**
1. Mở Squat. Đứng quay mặt thẳng vào máy, không đứng nghiêng.
2. App hiện lời nhắc quay ngang người. Chờ khoảng 5 giây thì nút "Bỏ qua cảnh báo" hiện ra. Bấm nút.
3. Vẫn quay mặt vào máy, squat 3 cái. Kết quả đúng:
   - app vẫn đếm;
   - app không nhắc lỗi tư thế;
   - màn hình hiện "Tập chậm và giữ an toàn".
4. Quay nghiêng lại, squat 3 cái nữa, cố ý xuống nông. Kết quả đúng: app chấm lại và nhắc lỗi xuống nông.
5. Thoát. Ghi lại xem từng bước có đúng không.

**Báo sai:**
1. Mở Squat. Hiệp 1: squat 8 cái, cái nào cũng cố ý xuống nông. App phải nhắc lỗi xuống nông.
2. Ở màn nghỉ, tìm lỗi xuống chưa đủ sâu và bấm "Báo sai".
3. Hiệp 2: squat 8 cái, vẫn xuống nông. Kết quả đúng: app không nói lời nhắc đó nữa. Log vẫn ghi lỗi, như vậy là
   đúng thiết kế.
4. Thoát. Ghi lại.

**Quay màn hình (chỉ làm nếu định quay màn hình máy A trong buổi đo chính):** vẫn mã `P00T`, bật quay màn hình,
tập plank 1 hiệp. Mình so FPS với hiệp plank ở mục 3.

Xong phần này thì đổi mã về `P00` nếu còn tập tiếp.

## 6. Kéo log về máy tính

"Kéo log" là chép các tệp nhật ký `vika_*.json` mà app ghi trong điện thoại sang máy tính. Mỗi hiệp là 1 tệp, mỗi
lần mở bài có thêm 1 tệp tổng của buổi.

**Cách 1: cáp USB (nhanh nhất).**
1. Cắm điện thoại vào máy tính. Gỡ lỗi USB đã bật từ lúc cài app. Nếu điện thoại hỏi "Cho phép gỡ lỗi USB" thì bấm
   Cho phép.
2. Mở PowerShell ở `D:\Vinafit-mobile`, chạy:
   ```powershell
   .\tools\eval\pull_phone_logs.ps1
   ```
   Script chép mọi tệp mới vào `tools\eval\phone_logs\` và in tên từng tệp. Cuối cùng nó ghi
   "Pulled N new or changed file(s)".
3. Muốn tự chép liên tục trong lúc tập thì thêm `-Watch`. Khi đó máy phải cắm cáp suốt buổi.

**Cách 2: không có cáp.**
1. Vào Hồ sơ, Cài đặt nghiên cứu, bấm "Chia sẻ tất cả tệp nhật ký".
2. Gửi qua Zalo, Drive hoặc email cho chính mình.
3. Tải về, bỏ hết vào `tools\eval\phone_logs\`.

Thư mục đó đã có log cũ ngày 20–21/11. Log cũ không có mã (ghi là `anon`), và cổng chỉ đọc log có mã `P00`, nên
không cần xoá.

## 7. Chạy cổng

```powershell
python tools\eval\p00_gate.py --logs tools\eval\phone_logs --out tools\eval\p00_result.csv
```

Mỗi hiệp in 1 dòng, ví dụ:

```
squat                ai       set 1  reps  8/8   cues 3/3  codes [depth;trunk]  PASS
```

- `reps 8/8`: app đếm 8, cần 8. Lệch 1 vẫn qua.
- `cues 3/3`: có 3 lời nhắc lỗi, cả 3 phát ra tiếng.
- `codes`: các mã lỗi app ghi trong hiệp.

Cuối bảng có 3 dòng tổng kết:
- `No log yet`: bài chưa có log `P00`, do chưa tập hoặc quên đặt mã.
- `No control set yet`: bài chính chưa có hiệp `control`.
- `Failing`: các bài trượt. Lý do nằm cuối dòng của từng hiệp:
  - `N reps`: app đếm lệch quá 1. Xem ghi chú xem có phải rep lỗi cố ý mà app không đếm không.
  - `no beep`: hiệp không có tiếng bíp, tức app chưa kích hoạt bài.
  - `codes not in catalog`: app ghi một mã lỗi mà danh mục chưa có. Mình sẽ sửa danh mục.
  - `fault cues have no audio`: có nhắc lỗi nhưng không phát tiếng, do thiếu file mp3.
  - `exercise not in catalog`: id bài lạ.

Hai việc cổng không kiểm được, bạn phải tự nghe lúc tập: giọng có phát thật không, và plank có gọi đúng võng
hông hay mông cao không.

## 8. Gửi lại cho mình

- Toàn bộ chữ in ra của lệnh ở mục 7, hoặc tệp `tools\eval\p00_result.csv`.
- Bảng ghi chú, chụp ảnh hoặc gõ lại.
- Log đã nằm trong `tools\eval\phone_logs\` thì mình đọc trực tiếp được.

Bài nào trượt thì sửa ngay tối nay. Không sửa kịp thì loại bài đó khỏi đợt đo và ghi lý do trong báo cáo (kế
hoạch mục 4.3).
