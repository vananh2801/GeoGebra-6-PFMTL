# GeoGebra-6-PFMTL
Script này dùng để update Electron và copy các thành phần mới cho GeoGebra 6 trên linux từ mac

Cách dùng:

```bash
chmod +x port-and-install-geogebra-v2.sh
./port-and-install-geogebra-v2.sh \
    --mac GeoGebra-Classic-6-MacOS-Portable-6-0-930-2.zip \
    --base GeoGebra-Linux64-Portable-6-0-804-0.zip \
    --electron-shell auto
```

- ```--electron-shell auto```: Tự tải binary file của Electron từ github chính chủ, đúng phiên bản đang chạy trên bản mac (khuyên dùng).
- ```--electron-shell skip```: Giữ nguyên Electron cũ hiện tại trên linux.
- ```--electron-shell /path.zip```: Sử dụng file .zip có sẵn trên máy.
