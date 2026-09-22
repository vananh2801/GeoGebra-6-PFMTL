# GeoGebra-6-PFMTL
Script này dùng để port GeoGebra Classic 6 từ bản Windows sang Linux. Script hỗ trợ tải bản Electron giống với của bản Windows từ nguồn Github chính chủ.

## Hướng dẫn sử dụng script
Yêu cầu cài sẵn: ```curl```, ```zip```, ```unzip```.

```bash
git clone https://github.com/vananh2801/GeoGebra-6-PFMTL 
cd ./GeoGebra-6-PFMTL
sudo chmod +x port-geogebra-6-PFMTL.sh
```

Tải file .zip của Windows cần port về, cho vào cùng thư mục với script, xài ```curl``` hay ```wget``` đều được. Tên file thường có dạng GeoGebra-Windows-Portable-X-Y-Z.zip.

Ở đây, ta có ba lựa chọn như sau:

1. Chỉ port và đóng gói thành .zip:
    ```bash
    sudo ./port-geogebra-6-PFMTL.sh --win GeoGebra-Windows-Portable-X-Y-Z.zip
    ```

2. Port, đóng gói thành .zip và cài vào máy:
    ```bash
    sudo ./port-geogebra-6-PFMTL.sh --win GeoGebra-Windows-Portable-X-Y-Z.zip --install
    ```

3. Port và cài vào máy, không đóng gói thành .zip:
    ```bash
    sudo ./port-geogebra-6-PFMTL.sh --win GeoGebra-Windows-Portable-X-Y-Z.zip --format none --install
    ```

Thêm cờ ```electron-shell``` để tuỳ chỉnh nguồn Electron:
- ```--electron-shell auto```: Tự động tải binary file của Electron từ github chính chủ, đúng phiên bản đang chạy trên bản Windows (mặc định, cần có mạng).
- ```--electron-shell /path/to/file.zip```: Sử dụng file .zip có sẵn trên máy.

## Hướng dẫn cài từ .zip

Đối với các máy cài bằng .zip được tải từ trang [Release](https://github.com/vananh2801/GeoGebra-6-PFMTL/releases) thì ta chỉ cần giải nén, sau đó chạy:

```bash
sudo chmod +x ./install.sh
sudo ./install.sh
```

Gỡ cài đặt:

```bash
sudo chmod +x ./uninstall.sh
sudo ./uninstall.sh
```

Các script này cần chạy dưới quyền sudo để bật sandbox, tăng tính bảo mật. Nếu ta không cấp quyền sudo thì các script vẫn chạy được và mặc định sẽ thêm cờ tắt sandbox trên electron.

## Link tải GeoGebra mới nhất cho Windows
Link tải bản Windows mới nhất hiện tại, có thể tải từ trang chủ chính thức:

https://download.geogebra.org/installers/6.0/GeoGebra-Windows-Portable-6-0-930-2.zip
