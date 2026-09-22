# GeoGebra-6-PFMTL
Script này dùng để port GeoGebra Classic 6 từ bản Windows sang Linux. Script hỗ trợ tải bản Electron giống với của bản Windows từ nguồn Github chính chủ.

Yêu cầu cài sẵn: ```curl```, ```zip```, ```unzip```.

```bash
git clone https://github.com/vananh2801/GeoGebra-6-PFMTL 
cd ./GeoGebra-6-PFMTL
chmod +x port-geogebra-6-PFMTL.sh
```

Ở đây, ta có ba lựa chọn như sau:

1. Chỉ port và đóng gói thành .zip:
    ```bash
    ./port-geogebra-6-PFMTL.sh --win GeoGebra-Windows-Portable-X-Y-Z.zip
    ```

2. Port, đóng gói thành .zip và cài vào máy:
    ```bash
    ./port-geogebra-6-PFMTL.sh --win GeoGebra-Windows-Portable-X-Y-Z.zip --install
    ```

3. Port và cài vào máy, không đóng gói thành .zip:
    ```bash
    ./port-geogebra-6-PFMTL.sh --win GeoGebra-Windows-Portable-X-Y-Z.zip --install
    ```

Thêm cờ ```electron-shell``` để tuỳ chỉnh nguồn Electron:
- ```--electron-shell auto```: Tự động tải binary file của Electron từ github chính chủ, đúng phiên bản đang chạy trên bản Windows (mặc định, cần có mạng).
- ```--electron-shell /path/to/file.zip```: Sử dụng file .zip có sẵn trên máy.

Link tải bản Windows mới nhất hiện tại, có thể lên trang chủ để tải:

https://download.geogebra.org/installers/6.0/GeoGebra-Windows-Portable-6-0-930-2.zip
