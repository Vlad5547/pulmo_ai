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

# Flutter app
flutter run
```

## Keeping this file current

**Always update this file at the end of any session that changed something.**
Standing instruction from the user — do it without being asked, as part of the
work, not as a separate request. What to refresh:

- the **State** section: what is done, what is running, what is still pending,
  and the current numbers (split sizes, `pos_weight`, hyperparameters, training
  results once they exist);
- the **Hard rules** and **Commands** sections whenever a decision, constraint
  or script changes;
- `ai/README.md` in the same pass when the pipeline or the model changes.

Update in place — keep it short and factual, do not let it grow into a
changelog.

## State (as of the last session)

- Data pipeline, split, Dataset/DataLoader, model, training/eval loop: done and
  smoke-tested. **No training run has been performed yet**; `ai/experiments/`
  is empty.
- Split: train 20 779 / val 4 453 / test 4 452, 23.94 % positive in each,
  0 shared patients. `pos_weight = 3.1775`, computed on train only.
- Hyperparameters for the first run: AdamW, lr 3e-4, weight decay 1e-4,
  batch 32, 30 epochs, early stopping patience 5, seed 42, num_workers 8.
- Flutter UI (Home / Analyze / Result / History) is complete and runs on a mock
  analysis service; swapping in the real model is one line in `lib/main.dart`.
- Thesis report (Ukrainian): `docs/PulmoAI_materialy_magisterska.docx`.

## Conventions

- Code, comments and `ai/README.md` are in English.
- Conversation with the user is in Russian; thesis documents in Ukrainian.
- Scripts print an ASCII-safe report and force UTF-8 stdout (the Windows
  console here is cp1251).
- Keep `ai/README.md` updated when the pipeline or the model changes.
