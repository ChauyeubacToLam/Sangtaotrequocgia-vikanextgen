# Vika: tiền đề thiết kế lại

Ghi ngày 2026-11-16. Đây là file tiền đề, chưa phải bản đặc tả. Nó ghi lại hướng suy nghĩ, các ý tưởng
đã nêu, phần đã thống nhất và phần còn mở. Mỗi mục ghi rõ đâu là ý tưởng của chủ dự án, đâu là nhận xét
của Claude trong buổi trao đổi.

## 1. Vì sao phải thiết kế lại

### Phản hồi của ban giám khảo (Đề cải tiến, phiên bản 1)

Điểm mạnh được ghi nhận, phải giữ và nâng cấp:

- Hỗ trợ người tự tập bằng camera điện thoại, có phản hồi tư thế và hướng dẫn bằng giọng nói.
- Xử lý 33 điểm MediaPipe ngay trên máy, kết hợp góc khớp và ngưỡng lỗi, công khai giới hạn thử nghiệm
  trước khi mở rộng tuyên bố hiệu quả.

Ba yêu cầu cải tiến:

1. Kiểm chứng phản hồi tư thế trên mẫu độc lập: video có nhãn của huấn luyện viên, đa dạng vóc dáng, góc
   máy, ánh sáng, trang phục, thiết bị. Báo cáo precision và recall từng lỗi, nhất là plank. Minh chứng:
   bảng số mẫu, confusion matrix theo tư thế, video nhận sai.
2. An toàn khi camera không đủ tầm nhìn: hướng dẫn đặt máy; khi thiếu điểm hoặc độ tin cậy thấp thì dừng
   đánh giá, cho bỏ qua hoặc sửa cảnh báo, nhắc tập an toàn. Minh chứng: demo thiếu điểm cơ thể, sai góc
   máy, thông báo "chưa đủ căn cứ".
3. Chứng minh giá trị của phản hồi AI so với video hướng dẫn hoặc huấn luyện viên: người dùng tập có và
   không có phản hồi AI, so với nhãn chuyên gia. Đo số lần sửa đúng tư thế, báo nhầm, mức hài lòng. Minh
   chứng: kết quả đối chứng, một ca sửa thành công và một ca thất bại.

### Vấn đề gốc

Nhận định của chủ dự án: tập bằng Vika hiện còn khó hơn tập theo video hay theo huấn luyện viên.

Nguyên nhân theo phần đọc code: camera đang đóng vai một cái cổng mà người tập phải vượt qua trước khi
được tập (đặt máy xa 2-3 m, đúng góc, giữ yên 3 giây, tạm dừng là phải giữ lại), và có 16 màn onboarding
trước buổi tập đầu tiên.

## 2. Tư duy thiết kế

Không bắt đầu từ khuôn "onboarding dài rồi mới cho tập" mà mọi app đang dùng. Bắt đầu từ quy trình cũ của
người tự tập ở nhà, đi từng bước, xem bước nào còn làm thủ công ("nông dân") và Vika thay được gì để tăng
năng suất tập luyện và chất lượng tập luyện.

### Quy trình cũ, 8 bước

Đây là mô hình suy ra từ lập luận, chưa có phỏng vấn người dùng để xác nhận.

| # | Bước | Người tập làm gì | Phần thủ công |
|---|---|---|---|
| 1 | Gặp vấn đề | Đau lưng, tăng cân, yếu, bác sĩ khuyên tập | Không biết vấn đề của mình cần loại bài nào |
| 2 | Tìm cách tập | Tìm YouTube, TikTok, hỏi bạn bè | Quá nhiều nội dung, không biết nguồn nào đúng |
| 3 | Chọn bài và mức tập | Chọn video theo cảm tính | Không đo thể lực ban đầu, dễ chọn quá nặng hoặc quá nhẹ |
| 4 | Chuẩn bị buổi tập | Trải thảm, mở video, dựng điện thoại hoặc TV | Nhanh, gần như không vướng |
| 5 | Học động tác | Xem người mẫu rồi bắt chước | Không ai xác nhận mình hiểu đúng |
| 6 | Tập | Làm theo video, tự đếm, tự giữ nhịp | Đuổi theo nhịp video, tạm dừng, tua lại, đếm sai; bài nằm sàn không nhìn được màn hình |
| 7 | Biết đúng hay sai | Soi gương, tự cảm nhận, hoặc không kiểm tra | Không rep nào được kiểm tra, lỗi lặp lại thành thói quen |
| 8 | Sau buổi và buổi sau | Tự nhớ đã tập gì, tự đoán khi nào tăng độ khó | Không ghi chép, không số đo tiến bộ, chững lại hoặc nhảy cóc rồi bỏ |

### Vika hiện tại so với quy trình này

- Hơn cách cũ: bước 3 (bài đánh giá và giáo án 7 tuần), bước 6 phần đếm, bước 8 (ghi lại, tăng tiến,
  check-in tuần).
- Kém cách cũ: bước 4 (dựng máy khắt khe), cộng 16 màn onboarding.
- Chưa chứng minh được: bước 7. Đây là chỗ cách cũ yếu nhất và Vika có thể thắng rõ nhất.
- Chưa đụng tới: bước 1 và 2.

## 3. Thiết kế mới

### 3.1 Vào thẳng vấn đề (bước 1, 2, 3)

Ý tưởng của chủ dự án:

- Sau khi đăng nhập, hỏi luôn "vấn đề của bạn là gì".
  - Đau mỏi, giãn cơ: chọn vùng đang đau mỏi.
  - Tăng cơ, giảm mỡ: chọn nhóm cơ muốn phát triển.
  - Tập theo bài của người nổi tiếng.
- Cho người dùng chọn cường độ luyện tập.

Nhận xét của Claude:

- Thay được 16 màn bằng 2-3 câu hỏi. Catalog đã có sẵn vùng cơ thể, nhóm cơ, mục tiêu, bài chống chỉ định
  khi đau, nên engine gợi ý hiện có dùng lại được.
- Tự chọn cường độ là quay lại kiểu đoán của cách cũ. Đề xuất: cho chọn mức khởi đầu, buổi đầu đo sức thật
  (số rep, giây giữ) rồi tự chỉnh. Buổi đầu thay luôn bài đánh giá hiện tại.
- Đề xuất cho tập thử trước, đăng ký sau buổi đầu.
- Nhánh đau mỏi cần câu sàng lọc: đau dữ dội, tê, sau mổ thì khuyên đi khám. `docs/state.md` ghi app từng
  bị App Store từ chối vì chỉ số sức khỏe thiếu trích dẫn.
- Bài của người nổi tiếng cần xin phép dùng tên và hình ảnh, không có cơ sở khoa học. Đề xuất bỏ khi đi thi.
- Chỉ đưa ra lựa chọn mà catalog đủ bài phủ. 40 bài không tạ khó hứa lên cơ theo từng nhóm.

### 3.2 Buổi tập (bước 4, 5, 6, 7)

Ý tưởng của chủ dự án:

- Hình nhân 3D tập mẫu thay cho video quay người thật.
- Ba chế độ:
  - Học động tác.
  - Kiểm tra động tác, dùng bộ chấm tư thế hiện tại.
  - Tập bài, đếm rep như hiện tại.
- Ghép động tác liền nhau, ví dụ chống đẩy 15 cái rồi plank 20 giây.

Nhận xét của Claude:

- Tách ba chế độ là phần mạnh nhất của thiết kế. Camera khắt khe hợp lý ở chế độ kiểm tra, vì người dùng
  chấp nhận khi đang được chấm. Chế độ tập thì nới ra, chủ yếu đếm. Đây là chỗ gỡ vấn đề "Vika khó hơn
  video".
- Ghép động tác có ràng buộc: mỗi bài hiện phải giữ yên 3 giây để kích hoạt và có yêu cầu góc máy riêng,
  plank chỉ chạy ngang máy. Chỉ ghép các bài chung vị trí đặt máy và chung chiều xoay, và phải bỏ bước
  kích hoạt lại giữa hai bài.
- Nên xếp cả buổi theo nhóm vị trí máy, để người tập dựng máy ít lần nhất.
- Đếm rep đang có. Theo `docs/reference/exercise-matrix.md`, vài bài đếm lỗi, cần sửa.

Về chuẩn "tập đúng":

- Chủ dự án khẳng định logic chấm trong code đã được kiểm tra theo huấn luyện viên. Chuẩn của hình mẫu 3D
  vì vậy lấy theo ngưỡng trong code.
- Ghi chú của Claude: trong repo chưa có số đo precision và recall, và phần đọc code (matrix) ghi nhận một
  số bài có lỗi logic, chưa chạy thử để xác nhận. Yêu cầu 1 của giám khảo đòi số đo trên mẫu độc lập, nên
  việc kiểm chứng vẫn phải làm dù ngưỡng đã được huấn luyện viên duyệt.

### 3.3 Ảnh trước và sau (bước 8)

Ý tưởng của chủ dự án: chụp và lưu ảnh trước và sau buổi tập.

Nhận xét của Claude:

- Cơ thể không đổi sau một buổi. Đề xuất chụp mỗi 1-2 tuần, cùng tư thế, có khung mờ để căn.
- Ảnh cơ thể là dữ liệu nhạy cảm: mặc định lưu trên máy, chỉ tải lên khi người dùng đồng ý.
- Sau mỗi buổi nên hiện số đo từ camera (rep đúng, giây giữ, biên độ). Đây là thứ video không có.

### 3.4 Phần còn thiếu, đã thống nhất

- Buổi sau tập gì: thiết kế chưa nói. Giữ engine tăng tiến và check-in tuần hiện có.
- Yêu cầu 1 và 3 của giám khảo: thiết kế này chưa tự trả lời. Vẫn cần bộ video có nhãn và thử nghiệm đối
  chứng.
- Khối lượng: thiết kế lại, hình nhân 3D, database mới và kiểm chứng là bốn việc lớn cùng lúc.

## 4. Hình nhân 3D

Chủ dự án đánh giá đây là phần khó nhất.

Quyết định kỹ thuật đề xuất:

- Render sẵn thành mp4 trong Blender, không dựng 3D chạy trực tiếp trong app. App đã phát được video mẫu
  (`videoAsset` trong `lib/models/exercise_definition.dart`, file trong `assets/video/`), nên không thêm
  thư viện 3D vào Flutter. Chỉ cần 3D trực tiếp khi muốn người dùng tự xoay hình nhân.
- Một hình nhân trung tính dùng chung cho mọi bài, tỷ lệ cơ thể giống người thật.
- Điều khiển Blender bằng Claude qua Blender MCP cho phần lặp lại: nhập, đặt tư thế, dựng camera, render.

Ba nguồn chuyển động:

| Nguồn | Hợp với | Điểm yếu |
|---|---|---|
| Đặt tư thế theo số đo góc | Bài giữ tĩnh: plank, cobra, sphinx, warrior, downward dog | Không hợp bài có chuyển động phức tạp |
| Quay người thật rồi trích chuyển động bằng AI | Bài có rep: squat, lunge, jumping jack | Bài nằm sàn hay bị trượt tay chân, lún sàn, phải sửa tay |
| Thư viện có sẵn (Mixamo) | Bài phổ biến, cần nhanh | Không ai bảo đảm form đúng, thiếu bài yoga |

Lợi thế của hình nhân so với video quay:

- Chọn được góc nhìn bất kỳ, kể cả đúng góc nghiêng mà app yêu cầu người tập đứng.
- Dựng được cặp "đúng và sai" cho từng lỗi bằng chính ngưỡng của bộ chấm, nên hình mẫu và bộ chấm nói
  cùng một chuẩn.
- Dựng được clip hướng dẫn đặt điện thoại, phục vụ yêu cầu 2 của giám khảo.

Bước thử đầu tiên: một bài plank với nhân vật Mixamo. Chuẩn lấy từ `lib/exercise/plank/plank.dart`: plank
cẳng tay, góc khuỷu dưới 125 độ, gối duỗi trên 140 độ, thân lệch khỏi phương ngang dưới 8 độ khi võng và
dưới 4 độ khi chổng hông. File FBX gốc của Mixamo không được phát tán, nên không đưa vào repo; chỉ đưa
video đã render.

## 5. Ba hướng nâng cấp điểm mạnh

Ba hướng này khác nhau ở lãng phí của cách cũ mà chúng loại bỏ. Chúng khớp với ba chế độ ở mục 3.2.

| Hướng | Lãng phí bị loại | Khớp với | Phụ thuộc kỹ thuật |
|---|---|---|---|
| 1. Sửa lỗi khép kín trong hiệp | Video không kiểm tra rep nào | Chế độ học và kiểm tra | Phân loại lỗi |
| 2. Buổi tập chạy theo nhịp người tập | Người tập phải đuổi theo đồng hồ của video | Chế độ tập, ghép động tác | Đếm rep, đo nhịp |
| 3. Tăng tiến theo số đo | Đoán buổi sau nên tăng hay giữ | Bước 8 | Cả hai, cộng thời gian |

Hướng 1: trong ngưỡng thì im lặng; ra ngoài ngưỡng thì nhắc một lỗi nặng nhất; theo dõi 2 rep kế tiếp; sửa
được thì xác nhận; nhắc 2 lần không sửa được thì chậm lại hoặc hạ độ khó; điểm không đủ tin cậy thì nói rõ
và không chấm.

Hướng 2: không chạm máy từ đầu đến cuối; giọng đếm bám theo chuyển động thật; chỉ đếm rep đủ biên độ; hiệp
dừng sớm khi kỹ thuật xuống.

Hướng 3: đo mốc riêng từng người ở buổi đầu; chỉ lên bài khó hơn khi tỷ lệ rep đúng đạt chuẩn ở các buổi
liên tiếp; báo cáo tuần bằng số đo, kèm tỷ lệ rep AI nhìn rõ.

### Nền chung cho năm điểm mạnh giám khảo nêu

| Điểm mạnh | Hôm nay | Nâng cấp |
|---|---|---|
| Tự tập qua camera | Dựng máy khắt khe, giữ yên 3 giây | Giọng nói dẫn dựng máy, tự bắt đầu khi thấy tư thế chuẩn bị |
| Phản hồi tư thế | Chưa có số đo độ chính xác | Chỉ bật cho bài đã qua kiểm chứng; bài chưa qua thì chỉ đếm |
| Giọng nói | Đếm và báo lỗi | Đủ để tập không cần nhìn màn hình |
| 33 điểm MediaPipe trên máy | Chặn cả frame khi điểm yếu | Độ tin cậy riêng từng lỗi; thống nhất iOS và Android |
| Công khai giới hạn | Nằm trong tài liệu | Thẻ kiểm chứng từng bài; app nói "chưa đủ căn cứ"; cho bỏ qua cảnh báo sai |

## 6. Thước đo và cách chứng minh

Chuẩn so sánh: nhãn của hai huấn luyện viên chấm độc lập trên video quay, không biết người tập thuộc nhóm
nào, dùng đúng danh sách lỗi của app.

- Năng suất: số giây từ lúc bấm bắt đầu đến rep hợp lệ đầu tiên; rep hợp lệ mỗi phút; liều hợp lệ thực
  hiện chia liều được giao; số lần chạm máy, tạm dừng, tua lại.
- Chất lượng: tỷ lệ rep đúng theo huấn luyện viên; tỷ lệ sửa thành công sau lời nhắc; tỷ lệ rep đúng sau
  7 ngày khi không còn phản hồi.
- Độ tin cậy của AI: precision và recall từng lỗi; số lần báo nhầm; mốc trần là mức đồng thuận giữa hai
  chuyên gia với nhau.

Thực nghiệm cho yêu cầu 3 của giám khảo (theo hướng 1): hai nhóm ngẫu nhiên cùng xem một video hướng dẫn.
Nhóm AI có phản hồi. Nhóm video tập theo video, app chạy ngầm ghi lỗi nhưng không nói. Thiết kế này cho cả
confusion matrix, kết quả đối chứng, và một ca thành công cùng một ca thất bại.

Cỡ mẫu: 26 người mỗi nhóm đủ phát hiện khác biệt lớn (d = 0,8); 17 người mỗi nhóm chỉ phát hiện được khác
biệt rất lớn (d = 1,0). Thiết kế mỗi người tập cả hai điều kiện cần khoảng 24 người cho khác biệt vừa đến
lớn (d = 0,6). Ngưỡng thắng phải chốt trước khi thu dữ liệu và phải có đồng ý ghi hình.

## 7. Database

Làm sau khi chốt thiết kế ở mục 3.

- App đang nối tới một dự án Supabase cũ mà chủ dự án không còn truy cập được.
- Repo chỉ có 3 migration và một tài liệu schema cho 10 bảng; code dùng 12 bảng. Dữ liệu catalog đầy đủ,
  RLS và cấu hình đăng nhập chỉ nằm ở dự án cũ.
- Catalog đóng gói trong app (`assets/data/exercise_catalog.json`) chỉ có 9 trường, trong khi model có
  khoảng 25 trường.
- Hướng làm: cứu catalog nếu app còn đọc được; thiết kế schema tối thiểu theo thiết kế mới; viết migration
  đầy đủ vào repo.

## 8. Câu hỏi còn mở

- Hạn nộp bài thi.
- App hôm nay còn đăng nhập và tải dữ liệu từ Supabase cũ được không.
- Có huấn luyện viên để gắn nhãn video kiểm chứng không.
- Có đủ máy Android và iPhone để thử không.
- Cắt phần nào trước nếu thời gian không đủ cho cả bốn việc lớn.

## 9. Tài liệu tham khảo

Đã tra ở mức tóm tắt trong buổi trao đổi, chưa đọc toàn văn:

- Sherwood 1988, Perceptual and Motor Skills 66(2):535-542. Chỉ phản hồi khi sai vượt ngưỡng giúp động
  tác ổn định hơn.
- Winstein & Schmidt 1990. Phản hồi thưa giữ kỹ năng tốt hơn phản hồi dày.
- Chiviacowsky & Wulf 2007, RQES 78(2):40-47. Phản hồi sau lần làm tốt giúp học tốt hơn.
- Wulf 2013, Int Rev Sport Exerc Psychol 6(1):77-104. Lời nhắc hướng vào kết quả động tác hiệu quả hơn.
- Sigrist et al. 2013, Psychon Bull Rev 20:21-53. Phản hồi tức thời hợp với người mới và nhiệm vụ phức tạp.
- Pareja-Blanco et al. 2017, Scand J Med Sci Sports 27:724-735. Dừng hiệp ở mức giảm tốc độ 20% cho sức
  mạnh tương đương với ít rep hơn; làm trên nam đã tập, squat có tạ.
- Lacroix et al. 2017, Sports Med 47(11):2341-2361. Tập có giám sát tốt hơn tự tập ở người cao tuổi.
- Biebl et al. 2021, JMIR 23(7):e26658. Đồng thuận app với chuyên gia 0,828, giữa hai chuyên gia 0,833.
- Chae et al. 2023, Interactive Journal of Medical Research, e37604. 20 người mới tập squat; nhóm dùng app
  chấm tư thế cải thiện sau 2 tuần, nhóm xem video thì không. Tiền lệ trực tiếp cho yêu cầu 3.
- ACSM 2009 position stand. Tăng tải dần; mức đồng thuận chuyên gia.

Từ trí nhớ, chưa tra lại: Wulf & Lewthwaite 2016, Sweller 1988, Michie 2009.
