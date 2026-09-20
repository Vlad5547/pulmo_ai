# PulmoAI

Master's thesis project: pneumonia (lung opacity) detection on chest X-rays.
Two parts in one repository — a Flutter app (`lib/`) and the research code
(`ai/`). Full technical detail lives in `ai/README.md`; this file is the short
orientation for a new session.

## Hard rules

- **Never modify the dataset.** `D:\datasets\pneumonia_dataset_2018\` is
  read-only: no renaming, moving, copying or writing. ~30 000 DICOM files.
- **Never touch the test split** outside `ai/src/training/evaluate.py`. Model
  selection happens on validation ROC-AUC only.
- **One model, one architecture: PulmoNet-7M**, a custom CNN in
  `ai/src/models/pulmonet.py` (7 065 953 parameters). No torchvision models, no
  ResNet/DenseNet/EfficientNet/VGG, no pretrained weights, no transfer
  learning, no second model for comparison. Everything trains from scratch.
- **Do not start a full training run without explicit confirmation.** Short
  checks (`smoke_train.py`, `pilot_run.py`, `--max-batches`) are fine.
- Input is **1 grayscale channel** `[B, 1, 224, 224]` — never duplicate into RGB.
- Labels: `1` = Lung Opacity, `0` = Normal and No Lung Opacity / Not Normal.

## Environment

```powershell
# Python 3.12 venv with CUDA torch 2.10.0+cu130 (RTX 5070 Ti)
D:\pulmo_ai\ai\.venv\Scripts\python.exe
```

Use that interpreter directly (no activation needed). Dependencies:
`ai/requirements.txt` (`python-docx` is installed on top, for the thesis report
generator only).

## Commands

```powershell
$py = "D:\pulmo_ai\ai\.venv\Scripts\python.exe"

# data (already produced; re-run only if the dataset or mapping changes)
& $py ai\src\data\inspect_dataset.py        # annotation <-> DICOM mapping
& $py ai\src\data\split_dataset.py          # patient-level stratified split

# checks (safe, seconds)
& $py ai\src\data\smoke_test.py             # 107 checks, data pipeline
& $py ai\src\data\test_dataset.py           # 9 checks, Dataset/DataLoader
& $py ai\src\training\test_metrics.py       # 5 checks, metrics
& $py ai\src\training\smoke_train.py        # 8 checks, one batch fwd/bwd/step
& $py ai\src\training\pilot_run.py          # loss must go down on a tiny subset

# training (needs confirmation) / evaluation (test split, once, at the end)
& $py ai\src\training\train.py --epochs 30
& $py ai\src\training\evaluate.py --split test

# inference on one DICOM with the trained checkpoint (read-only)
cd D:\pulmo_ai\ai; ..\ai\.venv\Scripts\python.exe -m src.inference.predict --dicom "<path.dcm>"

# CAM heatmap for one or more DICOM files (read-only)
cd D:\pulmo_ai\ai; ..\ai\.venv\Scripts\python.exe -m src.analysis.cam --dicom "<path.dcm>"

# export the CAM-capable graph and verify it against the classification model
cd D:\pulmo_ai\ai; ..\ai\.venv\Scripts\python.exe -m src.export.export_cam_onnx
cd D:\pulmo_ai\ai; ..\ai\.venv\Scripts\python.exe -m src.export.verify_cam_onnx --images 50

# export the checkpoint to ONNX and verify it (read-only for the checkpoint)
cd D:\pulmo_ai\ai; ..\ai\.venv\Scripts\python.exe -m src.export.export_onnx
cd D:\pulmo_ai\ai; ..\ai\.venv\Scripts\python.exe -m src.export.verify_onnx --images 100

# analysis of a finished experiment (read-only: no model, no inference)
& $py ai\src\analysis\plot_experiment.py

# regenerate the Ukrainian thesis report (embeds the figures above)
& $py docs\make_report.py

# thesis explanatory note, one file (Ukrainian, DSTU 3008-2015)
& $py docs\make_thesis.py         # -> docs\PulmoAI_poyasnyuvalna_zapyska.docx
# (make_front_matter.py / make_chapter1.py are its modules; running either one
#  alone emits only its own part, for drafting)

# Flutter app (runs PulmoNet-7M on-device via flutter_onnxruntime)
flutter run
flutter analyze                               # strict lint set, must stay clean
flutter test                                  # 106 unit/widget tests
flutter test integration_test -d <device>     # real ONNX parity test (needs a device)
flutter build apk --release --split-per-abi
flutter gen-l10n                              # after editing lib/l10n/*.arb

# launcher icon: redraw the artwork, then write the per-platform icon sets
& $py tool\make_app_icon.py
dart run flutter_launcher_icons

# DICOM parity: Dart reads the real .dcm, Python measures the effect on p
flutter test test/dicom_dataset_parity_test.dart
& $py ai\src\export\check_dicom_parity.py
```

## Keeping the documentation current

**Always record every change in all three places, in the same turn as the work
itself.** Standing instruction from the user — never wait to be asked:

1. **This file** — the **State** section (what is done, pending, current
   numbers), plus **Hard rules** and **Commands** whenever a decision,
   constraint or script changes.
2. **`ai/README.md`** — whenever the pipeline, the model, the results or the
   tooling change: add or update the relevant section.
3. **The thesis report** — `docs/make_report.py`, then regenerate
   `docs/PulmoAI_materialy_magisterska.docx`. New results, new figures, new
   components and newly discovered problems all belong in it (Ukrainian).
   Run `plot_experiment.py` first if figures changed.

Update in place — keep it short and factual, do not let any of the three grow
into a changelog.

## State (as of the last session)

- **First full training run is done** (2026-09-14, ~57 min on the RTX 5070 Ti).
  Experiment `pulmonet7m-scratch`, artefacts in
  `ai/experiments/pulmonet7m-scratch/` (`best.pt`, `last.pt`, `history.csv`,
  `results.json`, `config.json`).
- Result: **best validation ROC-AUC 0.8700 at epoch 13**, AUPRC 0.6821.
  Early stopping fired after epoch 18; `ReduceLROnPlateau` dropped the LR to
  1.5e-4 at epoch 16. Train/val ROC-AUC gap stayed under 0.01 until epoch 13 and
  reached 0.032 by epoch 18 — mild, late overfitting, caught by early stopping.
- Threshold study on validation (`best.pt`): F1 peaks at **0.6362 @ threshold
  0.65**, Youden's J peaks at 0.5682 @ 0.50. At the default 0.5 the model is
  recall-heavy (recall 0.81, precision 0.52) because of `pos_weight`.
- **Test evaluated once, at threshold 0.5** (`metrics_test.json`,
  `predictions_test.csv`): ROC-AUC **0.8739**, AUPRC 0.6794, accuracy 0.7779,
  precision 0.5228, recall 0.8293, F1 0.6413, specificity 0.7617, NPV 0.9341.
  Confusion matrix: TP 884, FP 807, FN 182, TN 2579. Test ≈ validation
  (0.8739 vs 0.8700), so the model generalises and the split held.
  **The test split is now spent** — no further tuning may be measured on it.
- Error structure on test: 17.1 % of Lung Opacity missed; false positives come
  almost entirely from `No Lung Opacity / Not Normal` (40.4 % of them) and
  barely from `Normal` (2.2 %) — the model separates "abnormal" well and
  struggles on "which abnormality".
- Split: train 20 779 / val 4 453 / test 4 452, 23.94 % positive in each,
  0 shared patients. `pos_weight = 3.1775`, computed on train only.
- Hyperparameters used: AdamW, lr 3e-4, weight decay 1e-4, batch 32, 30 epochs
  (stopped at 18), early stopping patience 5, seed 42, num_workers 8.
- Flutter UI (Home / Analyze / Result / History) is complete and runs the real
  model; `MockAnalysisService` is kept for tests.
- **The app reads DICOM.** `lib/services/dicom/dicom_decoder.dart` +
  `lib/services/radiograph_decoder.dart` route by file content, not extension.
  Supported: explicit/implicit VR little endian uncompressed, JPEG baseline
  (what RSNA uses), 8/16-bit, MONOCHROME1 inverted; anything else is refused
  with a typed error instead of being guessed at. The two scaling rules match
  `dicom_to_float_tensor` exactly. Parity: tensor 4.9e-03, probability
  **1.3e-03**, 0 verdicts changed — the gap is the baseline-JPEG decoder
  (`image` vs libjpeg differ by 1 LSB on ~4 % of pixels), not the parser.
  Verified by `test/dicom_dataset_parity_test.dart` (skips without the dataset)
  and `ai/src/export/check_dicom_parity.py`.
- **History is a local SQLite database**
  (`lib/services/sqlite_history_repository.dart`): survives restarts, copies the
  radiograph and the heatmap into the app directory, deletes them with the
  record. The old in-memory repository with three fake demo records is gone;
  `InMemoryHistoryRepository` remains for tests.
- **PDF report** (`lib/services/report_service.dart` + `printing`): one page,
  built on device from the stored record, shared through the platform sheet.
- **Localisation uk / en / de** — `lib/l10n/*.arb` → `flutter gen-l10n` →
  `lib/l10n/generated/`. Follows the device language; a picker in the home app
  bar overrides it (`lib/app/locale_controller.dart`). Dates go through `intl`
  with the active locale. `test/l10n_completeness_test.dart` fails the build on
  a missing, stale, empty or untranslated key.
- **App identity**: name **PulmoAI** everywhere the OS shows it (Android
  label, iOS `CFBundleName`/`CFBundleDisplayName`, macOS `PRODUCT_NAME`, web
  manifest and title, Windows `Runner.rc`, Linux window title). Bundle id is
  `ua.pulmoai.app` on every platform — the scaffolded `com.example.*` is gone,
  and the Kotlin package moved to `android/app/src/main/kotlin/ua/pulmoai/app/`.
  Launcher icon is drawn by `tool/make_app_icon.py` (lungs in viewfinder
  brackets, seed colour #0E7C86) into `assets/icon/`, and applied by
  `flutter_launcher_icons` — including the Android adaptive foreground and the
  Android 13+ monochrome variant. Changing the artwork means rerunning both.
- `showAboutDialog` was replaced by a plain `AlertDialog`: it always appends a
  "View licences" button and Flutter's own licence browser, which cannot be
  removed, is untranslated and is noise in a clinical tool. Do not reintroduce
  it. The Flutter scaffold's tutorial comments and `A new Flutter project`
  strings are gone from `pubspec.yaml`, `web/` and the platform runners.
- **Known flake, not ours**: `flutter test` occasionally reports a whole
  widget-test file as "did not complete" with no error. `-v` shows
  `flutter_tester process exited with code=-1073741819` — an access violation
  inside the Windows test engine (Flutter 3.47.2, engine a804b26164).
  Reproduced at ~1/10 with a minimal `MaterialApp` + `ListView` probe
  containing none of this project's code, at any `--concurrency`. Unit tests
  are unaffected. Just rerun; do not go looking for a bug in the widgets.
- Lints: `analysis_options.yaml` adds ~30 rules on top of `flutter_lints`
  (strict-casts/inference/raw-types, `unawaited_futures` and
  `non_exhaustive_switch_statement` as **errors**). `flutter analyze` is clean
  and must stay clean.
- Dead code removed: `DetectionBox` / `DetectionOverlay` (PulmoNet-7M is a
  classifier and always returned an empty list) and
  `ImagePreprocessingException` (decoding moved to `RadiographDecoder`).
- **ONNX export done and verified**: `ai/experiments/pulmonet7m-scratch/export/`
  (`pulmonet7m.onnx` 28.26 MB, fp32, opset 17, input `input` [1,1,224,224],
  output `logit` [1,1]; preprocessing stays outside the graph). Fidelity vs
  PyTorch on CPU: max 1.8e-07 over 100 images; vs the stored GPU predictions
  1.2e-04, which is TF32 arithmetic, not an export defect. Latency on desktop
  CPU 11.4 ms. Contract for Flutter is in `export_summary.json`.
- Mobile runtime (approved and integrated): **ONNX Runtime via
  `flutter_onnxruntime`**, fp32 opset 17, no INT8. The app runs the model
  **on-device, offline**: `assets/models/pulmonet7m.onnx` +
  `model_card.json`, `lib/services/image_preprocessor.dart`,
  `lib/services/onnx_analysis_service.dart`, injected in `main.dart`.
  `MockAnalysisService` is kept for tests.
- **Preprocessing parity is the fragile part.** The `image` package resize
  filters do not match PyTorch (`Interpolation.average` shifted the
  probability by 2.1e-2), so `ImagePreprocessor` implements the antialiased
  triangle filter by hand. Measured agreement with Python: **7.9e-07** on the
  probability for PNG input, **1.3e-03** for DICOM (JPEG decoder, see above).
  Never swap it out without re-running `test/preprocessing_parity_test.dart`
  and `test/dicom_dataset_parity_test.dart`.
- Release APK: arm64-v8a **61.8 MB** (26.3 MB model + ~19 MB ORT; DICOM +
  SQLite + PDF + 3 locales add ~1.3 MB). minSdk 21, no Gradle change needed.
  `file_picker` must stay **>= 13** — 8.x compiles against android-34 and fails
  `checkReleaseAarMetadata` against the current lifecycle plugin.
- **Verified on a real device** (Xiaomi 2306EPN60G, Android 15, arm64):
  warm-up 294 ms (session reused afterwards), 214 ms median per image, max |dp|
  vs desktop **7.889e-07** over the six fixtures, no verdict changed.
- **On-device CAM is live.** The app ships `pulmonet7m_cam.onnx` - the same
  `best.pt`, exported with a second output `features` [1,512,7,7] because ONNX
  Runtime cannot return undeclared internal tensors. `logit` is bit-identical to
  the classification-only export (0.0 over 50 images). The map is
  `sum_k w_k * features_k` -> ReLU -> /max -> upsample, with the 512 classifier
  weights carried in `model_card.json`; `lib/services/cam_service.dart` matches
  the Python implementation to 7.7e-07. CAM failures are caught and never block
  the classification result. On device: 6/6 heatmaps, +97 ms median.
- `pulmonet7m.onnx` (classification only) stays in
  `ai/experiments/pulmonet7m-scratch/export/` untouched; it is simply not the
  shipped asset any more.
- The integration test runs *on the device*, so its fixtures must be pushed
  first: `adb push test/fixtures/<file> /data/local/tmp/pulmoai_fixtures/`
  (not the app's own storage - `flutter test` reinstalls the app and wipes it).
- Inference + CAM are implemented on top of the existing checkpoint:
  `ai/src/inference/predict.py` (probability, class, threshold 0.5) and
  `ai/src/analysis/cam.py` (original / heatmap / overlay / result.json per
  image, plus ground-truth box overlays for positives, into
  `ai/experiments/pulmonet7m-scratch/cam/<SOPInstanceUID>/`). Inference
  preprocessing is asserted byte-identical to the Dataset, and stored test
  predictions reproduce to 1e-4. Tests: `src.inference.test_inference` and
  `src.analysis.test_cam`, 12/12.
- Figures and written analysis for the run:
  `ai/experiments/pulmonet7m-scratch/plots/` — ROC, PR, confusion matrix,
  training curves, `training_analysis.txt`, `error_analysis.txt`,
  `results_summary.json`. Regenerate with
  `ai/src/analysis/plot_experiment.py` (read-only, no inference).
- Thesis report (Ukrainian): `docs/PulmoAI_materialy_magisterska.docx`
  (13 sections, 18 tables, 8 embedded figures) — includes chapter 8
  "Результати навчання та оцінювання" with the full run analysis. Regenerate
  with `docs/make_report.py` after any new result.
- **Explanatory note: front matter + Chapter 1 are written**, assembled into one
  file `docs/PulmoAI_poyasnyuvalna_zapyska.docx` (43 pages) by
  `docs/make_thesis.py`, which composes `docs/make_front_matter.py` and
  `docs/make_chapter1.py` (figures in `docs/figures_ch1/`). Contents: title
  page, завдання, РЕФЕРАТ/ABSTRACT (one page each), перелік умовних позначень
  (28), ЗМІСТ with the full 4-chapter plan (chapter 4 now covers DICOM,
  history, the PDF report and localisation), ВСТУП, РОЗДІЛ 1 (7 subsections +
  висновки, 4 figures, 6 tables, 12 formulas), СПИСОК ВИКОРИСТАНИХ ДЖЕРЕЛ (48).
  Formatting verified against `docs/Методичні_Вказівки.docx` (DSTU 3008-2015):
  TNR 14, spacing 1.5, indent 15 mm, margins 25/15/20/20 mm, page number top
  right 12 pt (not on the title page), chapter heading centred in capitals on a
  new page, «Рис. 1.N», «Таблиця 1.N», formulas numbered within the chapter and
  separated by a blank line. Placeholders `____` remain for name, group,
  supervisor, order number, dates, page/figure counts and ЗМІСТ page numbers.
  Single source of truth for topic / object / subject / goal / novelty /
  practical value: the constants at the top of `make_front_matter.py` —
  Chapter 1 §1.7 repeats the same wording, keep them in sync.
  Formulas are plain Times New Roman text, not Microsoft Equation objects.
  Reference material kept in `docs/`: `Приклад1.docx`, `Приклад2.docx`
  (structure models) and `Дисертація_на_схожу_тему.docx` (style only).
  Chapters 2-4 are still to be written: add their compose() calls in
  `make_thesis.py` before `build_references`.

## Conventions

- Code, comments and `ai/README.md` are in English.
- Conversation with the user is in Russian; thesis documents in Ukrainian.
- Scripts print an ASCII-safe report and force UTF-8 stdout (the Windows
  console here is cp1251).
- Keep `ai/README.md` updated when the pipeline or the model changes.
