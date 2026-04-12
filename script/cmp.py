import sys
import cv2
from skimage.metrics import structural_similarity as calculate_ssim
from skimage.metrics import peak_signal_noise_ratio as calculate_psnr

def main():
    # Kiem tra du 2 doi so (duong dan anh) tu dong lenh
    if len(sys.argv) != 3:
        print("Cach su dung: python cmp.py <duong_dan_anh_1> <duong_dan_anh_2>")
        sys.exit(1)

    ref_image_path = sys.argv[1]
    proc_image_path = sys.argv[2]

    # Tai 2 anh tu duong dan duoc cung cap
    img1 = cv2.imread(ref_image_path)
    img2 = cv2.imread(proc_image_path)

    # Dung chuong trinh neu mot trong hai anh bi loi khong the tai
    if img1 is None:
        print(f"Loi: Khong the tai anh 1 tai {ref_image_path}")
        sys.exit(1)
    if img2 is None:
        print(f"Loi: Khong the tai anh da xu ly tai {proc_image_path}")
        sys.exit(1)

    # Thay doi kich thuoc anh da xu ly de khop voi anh goc neu khac biet
    if img1.shape != img2.shape:
        img2 = cv2.resize(img2, (img1.shape[1], img1.shape[0]))

    # Tinh toan chi so PSNR (ti le tin hieu tren nhieu)
    psnr_value = calculate_psnr(img1, img2)

    # Tinh toan chi so SSIM (do tuong dong cau truc)
    # Tham so channel_axis=-1 de ho tro anh da kenh (anh mau)
    ssim_value = calculate_ssim(img1, img2, channel_axis=-1)

    # Hien thi ket qua danh gia ro rang
    print(f" Anh goc: {ref_image_path}")
    print(f" Anh da xu ly: {proc_image_path}")
    print(f" PSNR: {psnr_value:.4f} dB")
    print(f" SSIM: {ssim_value:.4f}")

if __name__ == "__main__":
    main()