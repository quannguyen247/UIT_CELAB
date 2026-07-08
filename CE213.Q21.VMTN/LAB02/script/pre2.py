import sys
import cv2
import json
from pathlib import Path

def main():
    if len(sys.argv) != 2:
        print("Cach su dung: python pre2.py <duong_dan_anh_dau_vao>")
        sys.exit(1)

    input_path = sys.argv[1]
    project_root = Path(__file__).resolve().parent.parent
    temp_dir = project_root / "temp"
    txt_output_path = temp_dir / "input_rgb.txt"
    json_path = temp_dir / "meta2.json"

    # Dam bao thu muc luu file trung gian ton tai truoc khi ghi
    temp_dir.mkdir(parents=True, exist_ok=True)

    # Doc anh dau vao (OpenCV mac dinh doc theo BGR)
    img = cv2.imread(input_path, cv2.IMREAD_COLOR)
    if img is None:
        print("Loi: Khong the doc duoc anh dau vao.")
        sys.exit(1)

    # Chuyen anh tu he mau BGR sang RGB
    img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    h, w, _ = img.shape

    # Ghi thong tin kich thuoc ra file JSON
    meta_info = {
        "width": w,
        "height": h
    }
    with open(json_path, 'w') as f:
        json.dump(meta_info, f, indent=4)

    # Xuat du lieu pixel RGB ra file hex (24-bit: RRGGBB)
    with open(txt_output_path, 'w') as f:
        # Chuyen mang NumPy thanh chuoi byte lien tuc.
        # Dung ham bytes.hex() de dinh dang hex, chen '\n' sau moi 3 byte.
        # Them ky tu xuong dong cuoi de giong hanh vi vong lap ban cu.
        pixel_bytes = img.tobytes()
        hex_data = pixel_bytes.hex('\n', 3) + '\n'
        f.write(hex_data)

    print(f"Kich thuoc cho testbench -> WIDTH: {w}, HEIGHT: {h}")

if __name__ == "__main__":
    main()