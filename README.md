# GeoGebra-6-PFMTL
Script này dùng để update Electron và copy các thành phần mới cho GeoGebra 6 trên linux từ mac

Ta chỉ cần tải 2 file GeoGebra của linux và macOS về, để chung thư mục với .script, sau đó chạy:

```bash
chmod +x port-and-install-geogebra.sh
./port-and-install-geogebra.sh \
    --mac GeoGebra-Classic-6-MacOS-Portable-6-0-930-2.zip \
    --base GeoGebra-Linux64-Portable-6-0-804-0.zip \
    --electron-shell auto
    --format both
```

Thêm cờ ```--install``` để tự động cài đặt sau khi port.

Cờ ```electron-shell``` có ba tuỳ chọn như sau:
- ```--electron-shell auto```: Tự động tải binary file của Electron từ github chính chủ, đúng phiên bản đang chạy trên bản mac (khuyên dùng, yêu cầu có mạng).
- ```--electron-shell skip```: Giữ nguyên Electron cũ hiện tại trên linux.
- ```--electron-shell /path.zip```: Sử dụng file .zip có sẵn trên máy.

Cờ ```format``` có ba tuỳ chọn:
- ```--format deb```: Tạo .deb. Yêu cầu máy chạy distro dựa trên debian, có gói dpkg-deb, tự động bỏ qua nếu không có dpkg-deb.
- ```--format tar```: Tạo .tar.gz dùng để cài trên mọi distro. Chỉ cần giải nén rồi chạy ```install.sh``` bên trong.
- ```--format both```: Tạo cùng lúc .deb và .tar.gz (Mặc định).

Link tải bản linux mới nhất (cập nhất cuối 2023):

https://download.geogebra.org/installers/6.0/GeoGebra-Linux64-Portable-6-0-804-0.zip

Link tải bản macOS mới nhất hiện tại, có thể lên trang chủ để tải:

https://download.geogebra.org/installers/6.0/GeoGebra-Windows-Portable-6-0-930-2.zip
