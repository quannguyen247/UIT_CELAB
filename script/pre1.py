import sys
import cv2
import numpy as np
import json
from pathlib import Path

def main():
    # Kiem tra doi so truyen vao tu dong lenh
    if len(sys.argv) != 2:
        print("Cach su dung: python pre1.py <duong_dan_anh_dau_vao>")
        sys.exit(1)

    input_path = sys.argv[1]
    project_root = Path(__file__).resolve().parent.parent
    temp_dir = project_root / "temp"
    txt_output_path = temp_dir / "input_median.txt"
    pattern_output_path = temp_dir / "pattern.txt"
    json_path = temp_dir / "meta1.json"

    # Doc anh duoi dang anh xam
    img = cv2.imread(input_path, cv2.IMREAD_GRAYSCALE)
    if img is None:
        print("Loi: Khong the doc duoc anh dau vao.")
        sys.exit(1)

    print("Bat dau phat hien va luong tu hoa vien anh xam")
    # Ky thuat "Luong tu hoa" (Quantization):
    # Chia dai mau (0-255) thanh cac bac (o day la 16 bac).
    # Phep chia lay phan nguyen (//) roi nhan lai (*) se ep cac gia tri lan can nhau ve cung 1 moc.
    # Muc dich: Giam do bien thien do nhieu, giup tim mau chu dao (mau nen tron) de dang hon.
    quantization_step = 16
    quantized_img = (img // quantization_step) * quantization_step
    
    h, w = img.shape
    top, bottom, left, right = 0, h, 0, w
    # Nguong dong nhat: Yeu cau toi thieu 80% pixel tren vong vien phai cung mau sau luong tu
    # thi thuat toan moi cong nhan do la vien thay vi chi tiet anh.
    homogeneity_threshold = 0.80
    ring_colors_grayscale = []
    
    # Vong lap quet tu ngoai vao trong de phat hien vien tung lop mot (nhu boc hanh)
    while top < bottom and left < right:
        # Ky thuat trich xuat vien (Ring Extraction):
        # Cat 4 canh (tren, duoi, trai, phai) cua hinh chu nhat hien tai roi noi (concatenate) thanh 1 mang 1D.
        ring_pixels_q = np.concatenate([
            quantized_img[top, left:right],           # Canh tren
            quantized_img[bottom-1, left:right],      # Canh duoi
            quantized_img[top+1:bottom-1, left],      # Canh trai (bo 2 goc de khong bi trung lap)
            quantized_img[top+1:bottom-1, right-1]    # Canh phai
        ])
        
        if len(ring_pixels_q) == 0:
            break
            
        # Dung np.unique de tim cac mau co trong vien va dem so lan xuat hien (counts_q)
        colors_q, counts_q = np.unique(ring_pixels_q, return_counts=True)
        # np.argmax lay vi tri (index) cua mau pho bien nhat (dominant color)
        dominant_idx = np.argmax(counts_q)
        max_count = counts_q[dominant_idx]
        ratio = max_count / len(ring_pixels_q) # Tinh ty le ap dao
        
        # Kiem tra ty le mau dong nhat
        if ratio >= homogeneity_threshold:
            # Trich xuat dung cai vong vien do nhung lay tren ANH GOC (chua bi luong tu hoa)
            orig_ring = np.concatenate([
                img[top, left:right],
                img[bottom-1, left:right],
                img[top+1:bottom-1, left],
                img[top+1:bottom-1, right-1]
            ])
            dominant_q_color = colors_q[dominant_idx]
            
            # Ky thuat Masking (Mat na Boolean):
            # Loc mang True/False, vi tri nao co mau trung voi mau chu dao luong tu -> True
            mask = (ring_pixels_q == dominant_q_color)
            # Ap lop mat na nay vao anh goc de CHI LAY nhung pixel thuoc khoi mau chu dao
            matching_orig_pixels = orig_ring[mask]
            
            # Bau chon them 1 lan nua tren nhom mau goc de lay ra gia tri chuan xac nhat (khong suy hao do luong tu)
            colors_orig, counts_orig = np.unique(matching_orig_pixels, return_counts=True)
            true_dominant_color = int(colors_orig[np.argmax(counts_orig)])
            
            ring_colors_grayscale.append(true_dominant_color)
            
            # Thu hep khung hinh chu nhat vao trong 1 pixel de xet vong lap tiep theo
            top += 1
            bottom -= 1
            left += 1
            right -= 1
        else:
            # Ngay khi vong lap quat trung chi tiet anh (mau lon xon, ratio < 80%) -> Dung qua trinh tim vien
            break
            
    border = len(ring_colors_grayscale)
    if border == 0:
        # Van cho phep xu ly neu anh khong co vien dong nhat.
        # Truong hop nay se loc median tren toan bo anh voi BORDER=0.
        print("Canh bao: Khong phat hien vien dong nhat, dat BORDER=0.")

    # THAY DOI: Gioi han xuong 32 thay vi 64
    if border > 32:
        print(f"Loi: Do day vien ({border}px) vuot qua gioi han 32px cho kien truc pipeline moi.")
        sys.exit(1)
        
    # Ghi thong tin kich thuoc ra file JSON
    meta_info = {
        "width": w,
        "height": h,
        "border": border
    }
    with open(json_path, 'w') as f:
        json.dump(meta_info, f, indent=4)
        
    t = border
    b = h - border
    l = border
    r = w - border
    
    # ------------------------------------------------------
    # Ky thuat Edge Padding / Copying (Keo dem dan vien):
    # Thay vi de vien lam lech cua so truot Median, ta dem pixel sach nam o
    # ria anh sat ben vien bao phu lai toan bo khung vien bi nhieu.
    #
    # img[t:t+1, l:r]: Cat dung dai hang ngang dinh (top) tren loi anh sach
    # img[0:t, l:r]: La toan bo khoang trong vien 0->t. Gan de lai no bang dai ngang hang dinh.
    
    if border > 0:
        # Keo gian phan tren va duoi
        img[0:t, l:r] = img[t:t+1, l:r]
        img[b:h, l:r] = img[b-1:b, l:r]
        
        # Keo gian phan trai va phai (bao tron luon ca 4 goc)
        # Lay cot vien doc de de lai vien nhieu 2 ben. De luon qua toa do vien tren/duoi (mat 4 goc) de bo thanh vien kin.
        img[:, 0:l] = img[:, l:l+1]
        img[:, r:w] = img[:, r-1:r]
    # ------------------------------------------------------

    # Ky thuat dem ngoai cung (Halo Padding - np.pad):
    # Cua so quet IP Hardware cua sinh vien la 3x3 (quet bat dau tu goc trai tren vung [0,0]).
    # De cua 3x3 om tron anh tu [0,0] toi [W,H], phan ria phai co them 1 lop HALO day 1 pixel che chan ben ngoai.
    # mode='edge': lay gia tri cua diem lien ke ngoai cung cua anh goc copy y het ra ngoai va don them.
    padded_img = np.pad(img, ((1, 1), (1, 1)), mode='edge')
    
    # Xuat du lieu pixel ra file hex (duoi phang thanh mang 1D array - flatten) cho testbench
    with open(txt_output_path, 'w') as f:
        for pixel_val in padded_img.flatten():
            f.write(f"{pixel_val:02x}\n")
            
    # XU LY FORMAT CHO PATTERN: 32 pixel -> 8 dong x 32-bit
    # Lap day mang len du 32 pixel (bang 0) neu vien mong hon 32
    colors_32 = ring_colors_grayscale[:32] + [0]*(32 - len(ring_colors_grayscale))
    
    with open(pattern_output_path, 'w') as f:
        # Nhay buoc 4 de gom 4 pixel 8-bit thanh 1 block 32-bit
        for i in range(0, 32, 4):
            # Dich bit ghep 4 pixel lai, pixel i nam o LSB (phu hop logic dich bit tren Verilog)
            word32 = (colors_32[i+3] << 24) | (colors_32[i+2] << 16) | (colors_32[i+1] << 8) | colors_32[i]
            f.write(f"{word32:08x}\n")
            
    print(f"Kich thuoc cho testbench -> WIDTH: {w}, HEIGHT: {h}, BORDER: {border}")

if __name__ == "__main__":
    main()