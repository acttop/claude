import SwiftUI

struct ScannerView: View {
    @EnvironmentObject var vm: AssetViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showCamera = false
    @State private var showPicker = false
    @State private var showManual = false
    @State private var capturedImage: UIImage?
    @State private var recognizedAssets: [AssetEntry] = []
    @State private var isProcessing = false
    @State private var scanDate = Date()

    private let ocr = OCRService()

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if capturedImage == nil {
                    optionView
                } else {
                    resultView
                }
            }
            .navigationTitle("자산 스캔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCameraView { img in
                    capturedImage = img
                    processImage(img)
                }
            }
            .sheet(isPresented: $showPicker) {
                ImagePickerView(image: $capturedImage) { img in
                    processImage(img)
                }
            }
            .sheet(isPresented: $showManual) {
                ManualEntryView()
                    .environmentObject(vm)
                    .onDisappear { dismiss() }
            }
        }
    }

    // MARK: - Option Screen

    private var optionView: some View {
        ScrollView {
            VStack(spacing: 28) {
                // 아이콘 헤더
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 100, height: 100)
                        Image(systemName: "doc.viewfinder.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                    }
                    Text("자산 현황을 기록하세요")
                        .font(.title3.weight(.semibold))
                    Text("이미지 스캔 또는 직접 입력으로\n자산 데이터를 추가합니다")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                // 옵션 버튼
                VStack(spacing: 12) {
                    ScanOptionButton(
                        icon: "camera.fill",
                        title: "카메라로 촬영",
                        subtitle: "문서 카메라로 자동 인식",
                        color: .blue,
                        action: { showCamera = true }
                    )
                    ScanOptionButton(
                        icon: "photo.on.rectangle",
                        title: "사진 선택",
                        subtitle: "앨범에서 스크린샷 선택",
                        color: .purple,
                        action: { showPicker = true }
                    )
                    ScanOptionButton(
                        icon: "keyboard",
                        title: "직접 입력",
                        subtitle: "종목별 수량·가격 수동 입력",
                        color: .green,
                        action: { showManual = true }
                    )
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Result Screen

    private var resultView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 스캔된 이미지 미리보기
                if let img = capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                }

                if isProcessing {
                    processingView
                } else if recognizedAssets.isEmpty {
                    noResultView
                } else {
                    recognizedView
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("OCR 인식 중...")
                .foregroundStyle(.secondary)
        }
        .frame(height: 120)
    }

    private var noResultView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("자동 인식에 실패했습니다")
                .font(.headline)
            Text("이미지가 선명하지 않거나\n지원하지 않는 형식일 수 있습니다")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.subheadline)

            HStack(spacing: 12) {
                Button("다시 시도") {
                    capturedImage = nil
                    recognizedAssets = []
                }
                .buttonStyle(.bordered)

                Button("직접 입력") { showManual = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private var recognizedView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 날짜 선택
            HStack {
                Label("날짜", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                DatePicker("", selection: $scanDate, displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ko_KR"))
            }
            .padding(.horizontal)

            // 인식 결과
            VStack(alignment: .leading, spacing: 0) {
                Text("인식된 종목 \(recognizedAssets.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                ForEach(recognizedAssets) { asset in
                    AssetRowView(asset: asset)
                    if asset.id != recognizedAssets.last?.id {
                        Divider().padding(.leading, 70)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)

            // 저장 버튼
            Button {
                vm.addRecord(ScanRecord(date: scanDate, assets: recognizedAssets,
                                        imageData: capturedImage?.jpegData(compressionQuality: 0.5)))
                dismiss()
            } label: {
                Text("저장")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Button("다시 스캔") {
                capturedImage = nil
                recognizedAssets = []
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.secondary)
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        ocr.recognizeText(from: image) { assets in
            self.recognizedAssets = assets
            self.isProcessing = false
        }
    }
}
