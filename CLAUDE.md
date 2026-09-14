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

# export the checkpoint to ONNX and verify it (read-only for the checkpoint)
cd D:\pulmo_ai\ai; ..\ai\.venv\Scripts\python.exe -m src.export.export_onnx
cd D:\pulmo_ai\ai; ..\ai\.venv\Scripts\python.exe -m src.export.verify_onnx --images 100

# analysis of a finished experiment (read-only: no model, no inference)
& $py ai\src\analysis\plot_experiment.py

# regenerate the Ukrainian thesis report (embeds the figures above)
& $py docs\make_report.py

# Flutter app
flutter run
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
- Flutter UI (Home / Analyze / Result / History) is complete and runs on a mock
  analysis service; swapping in the real model is one line in `lib/main.dart`.
- **ONNX export done and verified**: `ai/experiments/pulmonet7m-scratch/export/`
  (`pulmonet7m.onnx` 28.26 MB, fp32, opset 17, input `input` [1,1,224,224],
  output `logit` [1,1]; preprocessing stays outside the graph). Fidelity vs
  PyTorch on CPU: max 1.8e-07 over 100 images; vs the stored GPU predictions
  1.2e-04, which is TF32 arithmetic, not an export defect. Latency on desktop
  CPU 11.4 ms. Contract for Flutter is in `export_summary.json`.
- Mobile runtime decision (approved): **ONNX Runtime via `flutter_onnxruntime`**,
  fp32 opset 17, **no INT8 for now**. Flutter still runs on the mock service -
  integration is the next step, not started.
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

## Conventions

- Code, comments and `ai/README.md` are in English.
- Conversation with the user is in Russian; thesis documents in Ukrainian.
- Scripts print an ASCII-safe report and force UTF-8 stdout (the Windows
  console here is cp1251).
- Keep `ai/README.md` updated when the pipeline or the model changes.
