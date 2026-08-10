# Phiếu Phản Ánh — K3 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời chi tiết cho từng câu hỏi phía dưới.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Lê Hoàng Việt  Mã học viên: 2A202601543

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Khi deploy ứng dụng lên môi trường Cloud Production (như Railway/Render), nếu ta quên cấu hình biến môi trường `AGENT_API_KEY`:
> - Nếu ta đặt giá trị mặc định là `"changeme"`, ứng dụng vẫn khởi động bình thường và mở public ra Internet. Các scanner bot tự động trên Internet sẽ nhanh chóng tìm thấy endpoint và thử các key mặc định phổ biến như `"changeme"`, từ đó gọi tự do vào API và tiêu sạch ngân sách tài khoản LLM của ta trước khi ta kịp phát hiện.
> - Ngược lại, nếu không có giá trị mặc định (Fail-fast), Pydantic sẽ ném lỗi `ValidationError` và container crash dừng ngay lập tức tại bước khởi động. Ta sẽ thấy log lỗi màu đỏ ngay trên dashboard deploy lúc còn đang quan sát, từ đó bổ sung key bí mật kịp thời trước khi có bất kỳ ai truy cập được vào hệ thống.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Dòng log JSON thu được:
> `{"event": "ask_completed", "level": "info", "timestamp": "2026-08-10T10:15:00.000000+00:00", "user_id": "sv01", "tokens_in": 12, "tokens_out": 45, "cost_usd": 0.00015}`
>
> Hai việc làm được với log JSON mà `print()` thông thường không làm được:
> 1. **Phân tích số liệu và vẽ Dashboard tự động**: Các hệ thống giám sát tập trung (Datadog, Grafana Loki, CloudWatch) có thể tự động parse các trường có cấu trúc như `cost_usd`, `tokens_in`, `tokens_out` để tính toán chi phí theo thời gian thực và biểu diễn lượng tiêu thụ token theo từng `user_id`.
> 2. **Tìm kiếm, lọc và thiết lập cảnh báo tự động (Alerting)**: Ta có thể dễ dàng truy vấn log có điều kiện (ví dụ: `level == 'error'` hoặc `cost_usd > 0.05`) để kích hoạt cảnh báo tức thì gửi về Slack/Telegram cho đội ngũ trực vận hành khi có user spam hoặc phát sinh chi phí bất thường.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~1020 MB |
| Multi-stage | ~165 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Phần dung lượng chênh lệch (~855 MB) bao gồm:
> - Trình biên dịch C/C++ (`gcc`, `g++`, `build-essential`), các header files hệ thống và công cụ build package chỉ dùng lúc cài đặt thư viện.
> - Thư mục cache tải về của `pip` (`~/.cache/pip`).
> - Bản thân base image `python:3.11` đầy đủ ban đầu chứa rất nhiều tiện ích hệ điều hành Debian không cần thiết cho runtime. Stage 2 chuyển sang `python:3.11-slim` chỉ copy thư viện Python đã cài đặt (`/install`) và mã nguồn, loại bỏ hoàn toàn các công cụ thừa.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> - Với Dockerfile tối ưu hiện tại: Toàn bộ các layer từ `COPY requirements.txt .` đến `RUN pip install ...` ở stage builder và copy `/install` sang runtime đều được tái sử dụng hoàn toàn từ cache (`CACHED`). Chỉ các layer `COPY app/ app/` và các bước phía sau phải chạy lại, quá trình build chỉ mất 1-2 giây.
> - Nếu đặt `COPY . .` lên trước `RUN pip install`: Mỗi khi sửa 1 ký tự trong code, layer `COPY . .` bị thay đổi checksum làm vô hiệu hóa (cache bust) toàn bộ các layer phía sau. Docker sẽ buộc phải chạy lại lệnh `RUN pip install` từ đầu, tải lại tất cả thư viện trên mạng, làm build mất hàng phút vô ích.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> - **Chuỗi sự kiện tấn công**: Kẻ tấn công khai thác lỗ hổng Remote Code Execution (RCE) hoặc Command Injection trong code Python để thực thi shell command bên trong container. Do container mặc định chạy quyền `root` (UID 0), tiến trình bị chiếm quyền sở hữu UID 0. Khi kết hợp với việc mount volume nhạy cảm (như docker socket `/var/run/docker.sock` hoặc thư mục `/etc` trên host), kẻ tấn công có thể breakout khỏi container và thao túng toàn bộ máy host với quyền root.
> - **Lệnh `USER appuser` cắt đứt chuỗi tấn công**: Lệnh này chuyển quyền thực thi của tiến trình trong container sang user thường (UID 10001). Khi bị exploit, kẻ tấn công chỉ có quyền hạn chế của `appuser`, không thể ghi đè file hệ thống trong container và không thể tận dụng quyền UID 0 để leo thang đặc quyền ra máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> - Số request tối đa có thể gửi trong 2 giây liên tiếp là **20 request** (gấp đôi hạn mức 10/phút).
> - **Cách đạt được**: Người dùng gửi 10 request ở giây `10:00:59` (thuộc block phút 10:00, hợp lệ). Đúng 1 giây sau vào lúc `10:01:00`, bộ đếm Fixed Window bị reset về 0, người dùng gửi tiếp ngay 10 request nữa ở giây `10:01:00` (thuộc block phút 10:01, vẫn hợp lệ). Tổng cộng có 20 request ập vào hệ thống chỉ trong 2 giây từ `10:00:59` đến `10:01:00`. Thuật toán Sliding Window tính trượt đúng 60s gần nhất sẽ chặn đứng kẽ hở này.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> - **Khác biệt**: Rate Limit kiểm soát **tần suất / tốc độ gửi request** (Requests/Time) nhằm bảo vệ hạ tầng máy chủ khỏi quá tải, nghẽn mạng; còn Cost Guard kiểm soát **tổng ngân sách tài chính** (USD/Tháng) tiêu thụ dựa trên số lượng token LLM để bảo vệ tài khoản tài chính.
> - **Tình huống Rate Limit cho qua nhưng Cost Guard chặn**: User chỉ gửi 1 request/phút (tốc độ rất chậm, đạt chuẩn rate limit). Tuy nhiên, mỗi request là tài liệu 100 trang tiêu tốn 50.000 tokens ($0.5/req). Sau 20 request trong tháng, user đã cạn kiệt ngân sách $10 ➔ Cost Guard chặn (402 Payment Required).
> - **Tình huống Cost Guard cho qua nhưng Rate Limit chặn**: Đầu tháng user còn nguyên $10 ngân sách. User chạy script spam 100 request liên tiếp trong 2 giây (mỗi câu chỉ 5 token, chi phí cực nhỏ). Ngân sách chưa cạn nhưng tần suất quá nhanh gây nguy cơ sập server ➔ Rate Limit chặn (429 Too Many Requests).

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> 1. Redis gặp sự cố hoặc nghẽn mạng tạm thời trong 30 giây.
> 2. Orchestrator (Docker/Kubernetes) gửi liveness probe vào endpoint chung và nhận phản hồi 503 (vì Redis không phản hồi).
> 3. Do liveness probe báo lỗi, Orchestrator hiểu rằng tiến trình container đã chết/treo và lập tức ra lệnh restart cưỡng bức cả 3 container agent.
> 4. Cả 3 container bị restart cùng lúc, làm gián đoạn và rớt toàn bộ các request đang xử lý dang dở của người dùng.
> 5. Khi Redis phục hồi sau 30 giây, cả 3 container vẫn đang trong giai đoạn khởi động lại, dẫn đến toàn bộ dịch vụ sập hoàn toàn (downtime 100%). Tách riêng `/ready` (chỉ ngắt traffic tạm thời mà không restart) sẽ bảo vệ cụm container an toàn.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?
Tại sao?

> - **Sự thay đổi**: Con số `history_length` sẽ tăng giảm bất thường không theo thứ tự (ví dụ gọi 5 lần liên tiếp nhận được: `0, 0, 2, 0, 4` thay vì tăng đều `0, 2, 4, 6, 8`).
> - **Lý do**: Nginx load balancer điều phối 5 request luân phiên qua 3 container A, B, C theo vòng tròn (Round-robin). Nếu lưu trong dict Python (trong RAM của container), mỗi container chỉ giữ dữ liệu của riêng nó mà không chia sẻ với các container khác. Khi request 2 rơi vào container B, B không thấy lịch sử ở container A, dẫn đến AI Agent bị "mất trí nhớ ngẫu nhiên". Chuyển sang Redis giúp toàn bộ container chia sẻ cùng một state duy nhất.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> - **Thông báo lỗi**: Deploy lên Cloud (Railway/Render) build thành công nhưng sau 1-2 phút platform báo `Health check failed / Timeout on port 8000` và tự động restart/terminate service.
> - **Cách tìm nguyên nhân**: Mở tab Deploy Logs trên dashboard, nhận thấy ứng dụng Uvicorn đang chạy cố định trên cổng 8000 (`--port 8000`), trong khi Cloud platform tự động cấp phát một cổng ngẫu nhiên thông qua biến môi trường `$PORT` (ví dụ `$PORT=10000`). Platform gửi HTTP probe kiểm tra vào cổng `$PORT` nhưng không nhận được phản hồi vì server lắng nghe sai cổng.
> - **Cách sửa**: Sửa lệnh `CMD` trong Dockerfile sang dạng shell form để tự động đọc biến `$PORT` khi chạy trên cloud: `CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]` và cập nhật `Settings` trong `app/config.py` đọc đúng biến `port`. Sau khi commit và push lại, Cloud health check xanh ngay lập tức.
