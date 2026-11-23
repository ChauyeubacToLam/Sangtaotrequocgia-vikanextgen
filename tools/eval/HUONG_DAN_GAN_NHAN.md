# Hướng dẫn gán nhãn video cho huấn luyện viên (24 bài)

Tài liệu này hướng dẫn HLV xem video người tập và điền bảng nhãn trong Excel hoặc Google Sheets, rồi xuất ra
**CSV UTF-8 (`.csv`)**. File mẫu: `tools/eval/coach_labels_template.csv`. Mã lỗi ở Mục 3 lấy đúng từ
`tools/eval/fault_catalog.csv`, cũng là mã ứng dụng ghi trong log.

---

## 1. Nguyên tắc chung

- **Chấm mù.** Clip đã bị xoá tiếng và đặt tên ngẫu nhiên. Không đoán người tập, không đoán điều kiện `ai`
  hay `control`, không mở log của ứng dụng. Mã người tập, điều kiện và hiệp lấy từ bảng tên clip mà điều phối
  viên đưa, không suy ra từ hình.
- **Mỗi dòng là 1 lần tập (`rep`) hoặc 1 lượt giữ (`hold`)** HLV quan sát thấy, ghi theo thứ tự thời gian.
- **Đếm cùng đơn vị với ứng dụng.** Mỗi bài có dòng "Kết thúc 1 lần" ở Mục 3. Bài nào ghi "mỗi bên tính 1 lần"
  thì một lượt trái và một lượt phải là 2 dòng.
- **Chấm theo mắt HLV**, không theo ngưỡng của ứng dụng. Nếu lỗi nhìn thấy rõ thì ghi, dù rất nhẹ.
- Lưu file trong Excel: **Save As → CSV UTF-8 (Comma delimited) (`*.csv`)** để giữ dấu tiếng Việt.

---

## 2. Ý nghĩa từng cột

| Cột | Bắt buộc? | Cách điền | Ví dụ |
|---|---|---|---|
| `coach_id` | Có | Mã HLV, giữ một mã xuyên suốt, không dấu cách. | `C1`, `C2` |
| `participant_id` | Có | Mã người tập theo bảng tên clip (viết hoa thống nhất). | `P01`, `P12` |
| `condition` | Có | Theo bảng tên clip: `ai` hoặc `control`. | `ai` |
| `exercise_id` | Có | Mã bài ở tiêu đề từng mục 3.x (chữ thường, có gạch dưới). | `mcgill_curlup` |
| `set_index` | Có | Số thứ tự hiệp của bài đó trong buổi tập, theo bảng tên clip (bắt đầu từ `1`). | `1` |
| `rep_n` | Có | Số thứ tự lần tập/lượt giữ do HLV tự đếm trong hiệp (`1, 2, 3, …`). Cả hiệp không có lần nào: ghi 1 dòng `rep_n = 0`, `counted = 0`. | `3` |
| `video_t_s` | Nên có | Số giây **từ đầu clip** (clip đã được cắt để bắt đầu đúng tiếng bíp của ứng dụng) **đến lúc kết thúc lần đó**. Không xác định được thì để trống. | `12.4` |
| `counted` | Có | `1` nếu HLV công nhận là 1 lần hợp lệ (bài giữ: giữ đủ thời gian). `0` nếu dở dang, nửa rep, hoặc gãy tư thế trước khi đủ thời gian. | `1` |
| `faults` | Có (trống nếu chuẩn) | Mã lỗi ở Mục 3 của đúng bài đó. Nhiều lỗi: nối bằng `;`, không dùng dấu phẩy. | `depth;tempo` |
| `note` | Tuỳ chọn | Ghi chú ngắn tiếng Việt. | `thả rơi ở đáy` |

---

## 3. Mã lỗi theo từng bài

Chỉ dùng đúng các mã chữ ở cột **Mã lỗi**, đúng chữ hoa/thường. Bài giữ (`hold`):

- Mỗi lượt giữ đủ thời gian là 1 dòng `counted = 1`; `video_t_s` là lúc hết thời gian giữ.
- Sập tư thế hoặc nghỉ trước khi đủ thời gian: `counted = 0`, ghi lý do ở `note`.
- **Plank:** chỉ ghi lỗi khi lỗi kéo dài gần nửa lượt giữ (khoảng 7 giây trên 15 giây).
- **Các bài giữ khác:** ghi lỗi khi lỗi thấy rõ và kéo dài từ khoảng 2 giây trở lên. Buổi hiệu chuẩn có thể chỉnh
  mốc này; nếu chỉnh, cả hai HLV dùng cùng một mốc cho toàn bộ đợt chấm.
- Thời gian giữ ghi dưới đây là mặc định. Nếu màn hình ứng dụng trong clip hiện số giây khác, theo màn hình.

### 3.1. `squat` — Squat (đếm rep)

Kết thúc 1 lần: đứng thẳng trở lại.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `depth` | Chưa xuống đủ sâu: ở đáy, đùi còn cao hơn hẳn mặt song song với sàn. |
| `trunk` | Thân trên đổ về trước quá nhiều hoặc ngả ra sau. |
| `tempo` | Thả rơi người xuống quá nhanh, nảy ở đáy, không kiểm soát pha hạ. |
| `sync` | Khi đứng lên, hông bật lên trước vai làm lưng gập xuống. |

### 3.2. `push_up` — Chống đẩy (đếm rep)

Kết thúc 1 lần: đẩy thẳng tay về tư thế plank cao.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `sag` | Thân không thẳng: hông võng xuống sàn hoặc mông nhổng cao (gộp chung một mã). |
| `depth` | Khuỷu gập quá ít, ngực còn cao đã đẩy lên. |
| `tempo` | Thả người xuống quá nhanh. |

### 3.3. `glute_bridge` — Cầu mông (đếm rep)

Kết thúc 1 lần: hông hạ chạm sàn.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `hip_extension` | Ở đỉnh, hông chưa lên tới đường thẳng vai–gối. |
| `hyperextension` | Ưỡn lưng dưới quá mức: hông vồng cao quá đường thẳng vai–gối. |
| `knee_angle` | Bàn chân đặt quá gần hoặc quá xa mông, góc gối ở đỉnh quá nhọn hoặc quá mở. |
| `speed_control` | Hạ hông rơi xuống quá nhanh. |
| `neck_head` | Nhấc đầu khỏi sàn hoặc gập cổ nhìn bụng. |

### 3.4. `plank` — Plank thấp (giữ, mỗi lượt 15 giây)

Kết thúc 1 lần: hết 15 giây giữ.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `Back` | Trục vai–hông–gót lệch: hông võng xuống hoặc mông nhổng cao (gộp chung một mã), kéo dài gần nửa lượt giữ. |
| `Neck` | Đầu rủ thấp hoặc ngửa cao, lệch khỏi đường tai–vai–hông. |
| `Knees` | Gối chùng hoặc gập trong lúc giữ. |

### 3.5. `lunge` — Lunge (đếm rep)

Kết thúc 1 lần: đứng thẳng trở lại sau khi hạ người.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `trunk` | Thân trên đổ về trước quá nhiều khi hạ người hoặc ngả ra sau. |
| `lumbar` | Lưng dưới ưỡn cong, hông đẩy ra trước khi ở đáy. |

### 3.6. `jump_squat` — Squat bật nhảy (đếm rep)

Kết thúc 1 lần: tiếp đất xong và đứng vững.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `takeoff_depth` | Lấy đà quá nông trước khi bật. |
| `landing_stiff` | Tiếp đất chân gần như thẳng, không chùng gối giảm lực. |
| `landing_depth` | Tiếp đất có chùng gối nhưng chưa đủ sâu. |
| `trunk` | Thân trên rạp về trước quá nhiều khi tiếp đất. |

### 3.7. `jumping_jack` — Jumping Jack (đếm rep)

Kết thúc 1 lần: tay chân về lại tư thế khép.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `arms` | Tay chưa vươn lên cao qua đầu. |
| `legs` | Chân mở chưa đủ rộng. |
| `tempo_fast` | Nhảy quá nhanh, động tác không trọn. |

### 3.8. `wall_pushup` — Chống đẩy tường (đếm rep)

Kết thúc 1 lần: đẩy tay thẳng trở lại.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `body_line` | Thân không thẳng: hông võng hoặc gập ở hông. |
| `cervical` | Ngửa cổ ra sau. |
| `head` | Đầu đưa ra trước, cằm chìa về phía tường. |
| `shoulder` | Rụt vai lên tai. |
| `hand` | Tay rời khỏi tường. |
| `foot` | Bàn chân xê dịch trong lúc tập. |
| `tempo` | Thả người vào tường quá nhanh. |

### 3.9. `situp` — Gập bụng (đếm rep)

Kết thúc 1 lần: nằm ngửa trở lại.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `jerking` | Giật hoặc quăng người để lên. |
| `rom` | Chưa lên tới vị trí cao nhất. |
| `stability` | Nhấc chân khỏi sàn. |

### 3.10. `leg_raises` — Nâng chân (đếm rep)

Kết thúc 1 lần: chân hạ về vị trí thấp.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `arms` | Tay không duỗi thẳng và khép sát hông. |
| `knee` | Gập gối khi nâng chân. |
| `pelvic` | Lưng dưới võng rời sàn, khung chậu không ổn định. |
| `rom` | Nâng chân chưa đủ cao. |
| `tempo` | Thả chân xuống quá nhanh. |

### 3.11. `vup` — Gập bụng chữ V (đếm rep)

Kết thúc 1 lần: nằm duỗi trở lại.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `jerking` | Giật người lên bằng quán tính. |
| `knee` | Gập gối khi gập người. |
| `rom` | Chưa gập đủ sâu (tay chưa gần chân). |
| `sync` | Thân trên và chân không lên cùng lúc. |
| `tempo` | Thả rơi người ở pha hạ. |

### 3.12. `mcgill_curlup` — Gập bụng McGill (đếm rep)

Kết thúc 1 lần: vai hạ về sàn.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `knee_extension` | Chân lẽ ra phải co lại duỗi thẳng. |
| `neck_pull` | Kéo cổ, cằm gập vào ngực thay vì giữ đầu thẳng hàng lưng. |
| `trunk_high` | Nâng thân lên quá cao (quá mức chỉ nhấc vai). |
| `trunk_low` | Chưa nhấc vai khỏi sàn. |

### 3.13. `dead_bug` — Dead Bug (đếm rep)

Kết thúc 1 lần: tay–chân của một bên thu về vị trí ban đầu. **Mỗi bên tính 1 lần.**

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `opposite_side` | Duỗi tay và chân cùng một bên, không phải tay–chân đối diện. |
| `alternate` | Không đổi bên giữa các lần. |
| `anti_extension` | Lưng dưới cong rời khỏi sàn. |
| `stable_limbs` | Tay hoặc chân trụ bị kéo xê dịch. |
| `floor_contact` | Tay hoặc chân chạm sàn khi duỗi. |
| `tempo` | Thả tay hoặc chân xuống quá nhanh. |

### 3.14. `bird_dog` — Bird Dog (đếm rep)

Kết thúc 1 lần: tay–chân của một bên thu về tư thế bò. **Mỗi bên tính 1 lần.**

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `opposite_side` | Duỗi tay và chân cùng một bên, không phải tay–chân đối diện. |
| `alternate` | Không đổi bên giữa các lần. |
| `alignment` | Tay hoặc chân duỗi chưa thẳng song song sàn. |
| `head` | Đầu cúi quá thấp. |
| `lumbar` | Đưa chân quá cao, lưng dưới võng. |
| `hold` | Giữ ở đỉnh chưa đủ thời gian app yêu cầu. |
| `trunk` | Hông lệch hoặc sụt về một bên. |

Ứng dụng còn ghi `MissingBody`, `Plank` khi mất điểm cơ thể hoặc người tập chưa vào tư thế. Đó không phải lỗi tư thế,
**HLV không gán các mã này.**

### 3.15. `mountain_climber` — Leo núi (đếm rep)

Kết thúc 1 lần: một gối co lên rồi thu về. **Mỗi chân tính 1 lần.**

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `rom` | Co gối chưa đủ về phía ngực. |
| `trunk_sag` | Lưng võng, hông chùng xuống. |
| `trunk_bounce` | Hông nảy lên xuống theo nhịp chân. |

### 3.16. `superman` — Superman (đếm rep)

Kết thúc 1 lần: tay chân hạ về sàn.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `elevation_arm` | Tay nâng chưa đủ cao. |
| `elevation_leg` | Chân nâng chưa đủ cao. |
| `hip` | Nhấc hông khỏi sàn. |
| `hold` | Giữ ở đỉnh chưa đủ thời gian app yêu cầu. |
| `lumbar` | Uốn cong lưng quá gắt. |

### 3.17. `tricep_dip` — Dip cơ tay sau (đếm rep)

Kết thúc 1 lần: duỗi thẳng tay lên trở lại.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `extension` | Ở đỉnh chưa duỗi thẳng tay. |
| `hip_thrust` | Đẩy hông lên xuống thay vì gập khuỷu. |
| `rom` | Gập khuỷu chưa đủ sâu. |
| `shrug` | Rụt vai lên tai. |

### 3.18. `side_plank_dip` — Plank nghiêng (giữ, mỗi lượt 15 giây)

Kết thúc 1 lần: hết 15 giây giữ plank nghiêng (app không đếm nhịp hạ hông).

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `shoulder` | Khuỷu tay trụ không nằm dưới vai. |
| `amplitude` | Thân mất đường thẳng vai–hông–gót. |

### 3.19. `seated_forward_fold` — Tư thế ngồi gập người (giữ, mỗi lượt 30 giây)

Kết thúc 1 lần: hết 30 giây giữ.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `knee` | Co gối. |
| `spine` | Gù lưng hoặc cúi đầu quá sâu thay vì gập từ hông. |
| `ankle` | Duỗi mũi chân ra xa thay vì hướng mũi chân lên. |
| `tempo` | Rời tư thế trước khi đủ thời gian giữ. |

### 3.20. `butterfly` — Tư thế con bướm (giữ, mỗi lượt 30 giây)

Kết thúc 1 lần: hết 30 giây giữ.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `knee` | Hai gối lệch nhau rõ rệt. |
| `posture` | Gập người hoặc gù lưng. |
| `shoulder` | Vai nghiêng hoặc lệch một bên. |
| `foot` | Hai bàn chân không áp vào nhau hoặc đặt quá xa người. |

### 3.21. `sphinx` — Tư thế nhân sư (giữ, mỗi lượt 30 giây)

Kết thúc 1 lần: hết 30 giây giữ.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `straight_arm` | Duỗi thẳng tay đẩy người lên thay vì chống cẳng tay. |
| `forearm` | Cẳng tay không áp song song sàn. |
| `upper_arm` | Cánh tay trên không vuông góc sàn, khuỷu không ở dưới vai. |
| `shrug` | Rụt vai lên tai. |
| `neck` | Ngửa cổ ra sau quá mức. |

### 3.22. `step_up` — Bước lên ghế (đếm rep)

Kết thúc 1 lần: bước xuống, hai chân về sàn. **Mỗi lần bước lên tính 1 lần**, người tập đổi chân trước giữa các lần.

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `trunk` | Đổ người ra trước khi đứng trên ghế. |
| `alternate` | Không đổi chân bước lên giữa các lần. |

### 3.23. `neck_side_stretch` — Giãn cổ nghiêng (giữ, mỗi lượt 20 giây)

Kết thúc 1 lần: hết 20 giây giữ một bên. **Mỗi bên tính 1 lần.**

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `shrug` | Nhún vai khi nghiêng đầu. |
| `shoulder` | Vai nghiêng theo đầu. |

### 3.24. `pushup_rotation` — Chống đẩy xoay người (đếm rep)

Kết thúc 1 lần: xoay mở tay xong và về plank cao. **Mỗi lần chống đẩy + xoay một bên tính 1 lần.**

| Mã lỗi | Mô tả lỗi nhìn trên video |
|---|---|
| `body_line` | Hông võng hoặc nhô khi chống đẩy. |
| `alternate` | Không đổi tay mở lên giữa các lần. |

---

## 4. Kiểm tra nhanh trước khi gửi file CSV

1. Không dòng nào trống `coach_id`, `participant_id`, `condition`, `exercise_id`, `set_index`, `rep_n`, `counted`.
2. Cùng một người tập không viết lúc `P07` lúc `p07` hoặc `P 07`.
3. Nhiều lỗi trong 1 lần tập ngăn bằng dấu chấm phẩy `;` (ví dụ `depth;trunk`).
4. Mã lỗi phải thuộc đúng bài đang chấm. Ví dụ `Back` chỉ có ở `plank`; `trunk` của `squat` và `trunk` của
   `lunge` là hai lỗi khác nhau.
5. Hai HLV chấm độc lập để đo độ đồng thuận: mỗi người một file (`labels_C1.csv`, `labels_C2.csv`), không xem
   file của nhau.
