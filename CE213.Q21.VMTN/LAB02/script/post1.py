import sys
import cv2
import numpy as np
import json
import re
from pathlib import Path

def main():
    # Kiem tra doi so truyen vao tu terminal
    if len(sys.argv) != 2:
        print("Cach su dung: python post1.py <duong_dan_anh_dau_ra>")
        sys.exit(1)

    final_output_path = Path(sys.argv[1])
    final_output_path_display = final_output_path.as_posix()
    project_root = Path(__file__).resolve().parent.parent
    temp_dir = project_root / "temp"
    hw_input_txt = temp_dir / "output_median.txt"
    json_path = temp_dir / "meta1.json"

    print(" Bat dau khoi phuc anh tu ma hex")
    
    # Doc metadata tu file json de lay chieu cao va rong
    with open(json_path, 'r') as f:
        data = json.load(f)
        
    h = data['height']
    w = data['width']
    
    # Nap du lieu hex tu file ket qua do ModelSim xuat ra
    if hw_input_txt.exists():
        input_file = hw_input_txt
    else:
        print(f" Loi: Khong tim thay file output_median.txt tai {hw_input_txt}")
        sys.exit(1)
    
    hex_data = []
    unknown_count = 0
    with open(input_file, 'r') as f:
        for raw_line in f:
            # Cat bo comment theo format ModelSim writememh
            line = raw_line.split('//', 1)[0].strip()
            if not line:
                continue

            for token in line.split():
                if token.startswith('@'):
                    continue
                if re.fullmatch(r'[0-9a-fA-F]+', token):
                    hex_data.append(token)
                elif re.fullmatch(r'[xXzZ]+', token):
                    # Du lieu chua xac dinh tu mo phong -> thay tam bang 0 de dung anh
                    hex_data.append('00')
                    unknown_count += 1

    if unknown_count > 0:
        print(f" Canh bao: Co {unknown_count} pixel o trang thai x/z, da thay bang 00.")
        
    # Xac thuc so luong pixel co khop voi kich thuoc anh khong
    if len(hex_data) != (h * w):
        print(f" Loi: So luong pixel khong khop. Mong doi {h * w}, nhan duoc {len(hex_data)}.")
        sys.exit(1)
        
    # Parse du lieu tu hex ve mang numpy 2 chieu (anh grayscale 8-bit)
    pixels = [int(val, 16) for val in hex_data]
    final_image = np.array(pixels, dtype=np.uint8).reshape((h, w))

    # Ghi anh ket qua vao o dia
    if not cv2.imwrite(str(final_output_path), final_image):
        print(f" Loi: Khong the ghi anh dau ra tai {final_output_path_display}")
        sys.exit(1)
    print(f" Khoi phuc anh thanh cong va da luu tai {final_output_path_display}")

if __name__ == "__main__":
    main()