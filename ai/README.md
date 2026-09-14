# PulmoAI — AI subproject

Research code for *"PulmoAI — AI-based pneumonia detection from chest X-ray
images"*. This folder is independent from the Flutter app; it holds the data
pipeline, and later the training/export code for the model that the app will
consume.

Current state: **data pipeline + model/training scaffolding**. Dataset
analysis, annotation↔DICOM mapping, patient-grouped split, PyTorch
`Dataset`/`DataLoader`, the PulmoNet-7M custom CNN (from scratch) and the
training/evaluation loop are in place and smoke-tested. **No training run has
been started** — it needs explicit confirmation.

---

## 1. Dataset

RSNA Pneumonia Detection Challenge 2018, **adjudicated** annotation export
(MD.ai project export), stored locally and **never modified, moved or copied**
by this code.

```
D:\datasets\pneumonia_dataset_2018\
├── images\
│   └── <StudyInstanceUID>\
│       └── <SeriesInstanceUID>\
│           └── <SOPInstanceUID>.dcm          30 000 files, 1 per study
└── pneumonia-challenge-annotations-adjudicated-kaggle_2018.json   ~52 MB
```

### DICOM

Verified with pydicom on the real files:

| Attribute | Value |
|---|---|
| Modality | `CR` (all 30 000) |
| SOPClassUID | `1.2.840.10008.5.1.4.1.1.7` (Secondary Capture) |
| BodyPartExamined | `CHEST` |
| ViewPosition | `PA` 16 248 / `AP` 13 752 |
| Rows × Columns | `1024 × 1024` (all) |
| PhotometricInterpretation | `MONOCHROME2`, 8 bits stored |
| PatientID | anonymised GUID (1 patient ↔ 1 study) |

The three directory levels are **exactly** the UIDs from the DICOM header:
`images/<StudyInstanceUID>/<SeriesInstanceUID>/<SOPInstanceUID>.dcm`. The
inspection script re-verifies this for every file (0 mismatches on the current
copy) instead of trusting the layout.

### Annotation JSON

Top level is an MD.ai project, not a flat list:

```jsonc
{
  "id": "x9N20BZa",
  "name": "ChestX-ray14 subset: Pneumonia",
  "labelGroups": [                      // 7 groups, 47 labels
    { "id": "G_qwj", "name": "Calculated",
      "labels": [ { "id": "L_v8n", "name": "Lung Opacity",
                    "type": "local", "scope": "instance",
                    "annotationMode": "bbox" }, ... ] }
  ],
  "datasets": [
    { "id": "D_e57",
      "studies":     [ { "StudyInstanceUID": "...", "number": 7,
                         "findings": "" } ],          // 30 000
      "annotations": [ { "id": "A_e5227e",
                         "StudyInstanceUID":  "1.2.276.0.7230010.3.1.2...",
                         "SeriesInstanceUID": "1.2.276.0.7230010.3.1.3...",
                         "SOPInstanceUID":    "1.2.276.0.7230010.3.1.4...",
                         "labelId": "L_v8n",
                         "annotationNumber": 1,
                         "width": 1024, "height": 1024,     // reference frame
                         "data": { "x": 398.8, "y": 242.4,
                                   "width": 358.4, "height": 609.6 },
                         "note": null, "createdById": "U_rk3" } ]  // 83 809
    }
  ]
}
```

Key points:

* **`data`** holds the bounding box in pixels: `x`, `y` = top-left corner,
  `width`, `height` = size. `width`/`height` **on the annotation itself** are
  the reference frame (always 1024×1024, i.e. identical to the DICOM
  `Columns`/`Rows` — verified for all 11 390 boxes, no box leaves the frame).
* `data` is `null` for global (image-level) labels such as *Normal*.
* Label groups: `Default group`, `QA`, `Team 1`, `Team 2`, `Team 2a`,
  **`Calculated`**, `Adjudication`. The per-team groups are the raw reader
  annotations; **`Calculated` is the adjudicated ground truth** and the only
  group used for labels/boxes here. It contains exactly the three challenge
  classes: `Lung Opacity` (with boxes), `Normal`, `No Lung Opacity / Not Normal`.
* 98 annotations have no `SOPInstanceUID` — they are study-scope labels
  (`Question Addressed`) and are ignored for image-level mapping.

### How JSON is linked to DICOM

**Join key: `SOPInstanceUID`** (unique per image; there is exactly one image
per study/series in this dataset). `StudyInstanceUID` and `SeriesInstanceUID`
are used as a cross-check: the script asserts that the study UID of the matched
annotation equals the one in the DICOM header (0 conflicts). The directory
names are *not* trusted as the source of truth — every UID comes from the
header itself.

---

## 2. Setup

```powershell
cd D:\pulmo_ai
python -m venv ai\.venv
ai\.venv\Scripts\python.exe -m pip install -r ai\requirements.txt
```

Dataset paths are configured in one place — `ai/src/config.py` — and can be
overridden without touching code, via environment variables or `ai/.env`
(copy `ai/.env.example`):

| Variable | Meaning | Default |
|---|---|---|
| `PULMOAI_DATASET_ROOT` | dataset root | `D:\datasets\pneumonia_dataset_2018` |
| `PULMOAI_IMAGES_DIR` | DICOM root | `<root>\images` |
| `PULMOAI_ANNOTATIONS` | annotation JSON | first `*annotations*.json` in root |
| `PULMOAI_PROCESSED_DIR` | output folder | `ai\data\processed` |

---

## 3. `ai/src/data/inspect_dataset.py`

```powershell
ai\.venv\Scripts\python.exe ai\src\data\inspect_dataset.py            # full run (~20 s)
ai\.venv\Scripts\python.exe ai\src\data\inspect_dataset.py --limit 500  # smoke run
ai\.venv\Scripts\python.exe ai\src\data\inspect_dataset.py --no-write   # report only
ai\.venv\Scripts\python.exe ai\src\data\inspect_dataset.py --out <dir>  # other output dir
```

What it does:

1. parses the annotation export and prints its real structure (groups, labels,
   counts, which labels carry boxes);
2. walks `images/` recursively for `*.dcm`;
3. reads **headers only** — `stop_before_pixels=True` plus an explicit tag
   list, one file at a time. Pixel data is never decoded, memory stays flat;
4. joins annotations to files on `SOPInstanceUID`, validating study/series and
   the directory layout;
5. prints the statistics report (see below);
6. writes the mapping files.

It is strictly read-only with respect to the dataset: nothing under
`PULMOAI_DATASET_ROOT` is created, renamed, moved or written.

### Output — `ai/data/processed/`

Only paths, UIDs, labels and coordinates. **No DICOM files are copied.**

| File | Rows | Content |
|---|---|---|
| `dataset_mapping.csv` | 30 000 | one row per DICOM image |
| `bounding_boxes.csv` | 11 390 | one row per adjudicated box |
| `unmatched_annotations.csv` | 0 | ground-truth annotations with no DICOM file |
| `dataset_summary.json` | — | machine-readable version of the report |

`dataset_mapping.csv` columns:

```
sop_instance_uid, study_instance_uid, series_instance_uid,
relative_path,          # relative to images/, e.g. <study>\<series>\<sop>.dcm
class_label,            # Lung Opacity | Normal | No Lung Opacity / Not Normal | ""
target,                 # 1 for Lung Opacity, else 0
num_boxes, matched,
modality, body_part, view_position, rows, columns,
patient_id, patient_age, patient_sex, transfer_syntax,
raw_reader_labels       # only for unmatched images: "Team 1::Exclude;..."
```

`bounding_boxes.csv` columns:

```
sop_instance_uid, study_instance_uid, relative_path,
annotation_id, annotation_number, label_name,
x, y, width, height,          # pixels, top-left origin
ref_width, ref_height,        # annotation reference frame (1024x1024)
dicom_columns, dicom_rows     # actual image size, for a scaling sanity check
```

### Results on the current copy

```
DICOM files found                30 000     unique studies      30 000
headers read successfully        30 000     unique series       30 000
path/header UID mismatches            0     duplicate SOP UIDs       0

matched to a ground-truth label  29 684
DICOM without a label               316     (210 reader-annotated but never
                                             adjudicated, 106 marked "Exclude")
annotations without a DICOM file      0

Lung Opacity                      7 106     (23.94 %)
Normal                            9 790     (32.98 %)
No Lung Opacity / Not Normal     12 788     (43.08 %)
bounding boxes                   11 390     (1 box: 3 030 images, 2: 3 892,
                                             3: 160, 4: 24)
```

---


## 4. Classes and what is excluded

Binary task, exactly as in the RSNA challenge:

| Adjudicated class (`Calculated` group) | `target` | Images |
|---|---|---|
| `Lung Opacity` | **1** (positive) | 7 106 |
| `Normal` | 0 | 9 790 |
| `No Lung Opacity / Not Normal` | 0 | 12 788 |

`No Lung Opacity / Not Normal` stays a *negative*: the radiograph is abnormal,
but not with an opacity that looks like pneumonia. Keeping it negative is what
makes the task clinically meaningful — the model has to separate pneumonia from
other pathology, not just "sick vs healthy".

**316 images are excluded from training** (`matched = 0`): they have no label in
the adjudicated `Calculated` group. 106 were marked `Exclude` by a reader
(unusable study), and 210 were annotated by the reader teams but never received
a final adjudicated label. Inventing a label for them would inject noise into
both training and evaluation, so they stay in `dataset_mapping.csv` with
`matched = 0` and their `raw_reader_labels`, and are filtered out by the
Dataset. Usable images: **29 684**.

---

## 5. Split — `ai/src/data/split_dataset.py`

```powershell
ai\.venv\Scripts\python.exe ai\src\data\split_dataset.py
ai\.venv\Scripts\python.exe ai\src\data\split_dataset.py --seed 7
ai\.venv\Scripts\python.exe ai\src\data\split_dataset.py --train 0.8 --val 0.1 --test 0.1
ai\.venv\Scripts\python.exe ai\src\data\split_dataset.py --no-write   # statistics only
```

**Ratio 70 / 15 / 15.** With 29 684 images that leaves ~20 800 for training and
~4 450 in each held-out set — about 1 070 positives each, enough for a stable
AUROC/AUPRC and for tuning the decision threshold on validation without
touching test. 80/10/10 would shrink the held-out positives to ~710 and make
model comparison noisier; a smaller training share wastes data the model needs
for a 24 % minority class.

**Grouped by patient.** The group key is `patient_id`, read from the DICOM
`PatientID` tag (an anonymised GUID) — a real field in the data, not a derived
or invented one. Two images of the same patient share anatomy, devices and
often the same illness episode; if they land in different splits, the model can
recognise the patient instead of the disease and validation becomes optimistic.
In this export `PatientID` is 1:1 with `StudyInstanceUID` (30 000 unique IDs for
30 000 images), so grouping currently changes nothing — it is applied anyway so
the pipeline stays correct if follow-up studies are added. After splitting, the
script verifies that no patient appears in two splits and fails loudly if one
does.

**Stratified.** Patients are bucketed by label (a patient counts as positive if
any of their images is positive) before being dealt out, so the positive rate is
identical in all three sets.

**Reproducible.** Patient IDs are sorted before shuffling with
`numpy.random.default_rng(seed)`, so the result depends on the seed alone and
not on pandas row order — re-running with the same seed produces a
byte-identical `dataset_split.csv`.

Result with the default seed 42:

```
split    images  patients  positive  negative  pos rate    boxes
----------------------------------------------------------------
train    20 779    20 779     4 974    15 805    0.2394    7 945
val       4 453     4 453     1 066     3 387    0.2394    1 736
test      4 452     4 452     1 066     3 386    0.2394    1 709

patients in more than one split: 0
```

Written to `ai/data/processed/`: `dataset_split.csv` (`sop_instance_uid,
study_instance_uid, patient_id, class_label, target, num_boxes, relative_path,
split`) and `split_summary.json`.

---

## 6. Dataset and DataLoader — `ai/src/data/dataset.py`

```python
from src.data.dataset import RsnaPneumoniaDataset, build_dataloader, build_dataloaders

train = RsnaPneumoniaDataset(split="train")      # augmentation on
val = RsnaPneumoniaDataset(split="val")          # augmentation off
loader = build_dataloader(train, batch_size=16)
loaders = build_dataloaders(batch_size=16)       # train/val/test at once
```

One item is a dict:

| Key | Type | Meaning |
|---|---|---|
| `image` | `float32 [C, S, S]` | normalised image, `C`/`S` from the config |
| `label` | `float32` scalar | 1.0 = Lung Opacity, 0.0 otherwise |
| `boxes` | `float32 [N, 4]` | xyxy in **resized** pixels (`N = 0` for negatives) |
| `boxes_normalized` | `float32 [N, 4]` | xyxy in 0..1 — the format the Flutter `DetectionBox` uses |
| `sop_instance_uid`, `relative_path`, `class_label` | `str` | provenance |

Memory behaviour: only the two CSVs live in RAM. `__getitem__` opens one DICOM,
decodes its pixels, transforms it and releases it — nothing is cached, so peak
memory is one image regardless of split size. Files are opened read-only and
never written back.

`collate_samples` keeps `boxes` as a list (images carry a different number of
them), so a detector can reuse the same loader later.
`dataset.class_weights()` returns the `pos_weight` for `BCEWithLogitsLoss`
(3.18 on train); `positive_count` / `negative_count` are available for
sampler-based balancing.

### Preprocessing — `ai/src/data/preprocessing.py`

1. `pixel_array` → float32, divided by the real range of `BitsStored` (8 bit
   here) rather than a hard-coded 255;
2. `MONOCHROME1` is inverted so "bright = dense" holds for any source (this
   dataset is entirely `MONOCHROME2`);
3. bilinear antialiased resize to `image_size`; boxes scale with the same
   factor;
4. train only: rotation ±7°, brightness/contrast ±20 %. **Horizontal flip
   exists but is off by default** — left/right is diagnostically meaningful on
   a chest radiograph (heart position, situs), so mirroring teaches anatomy
   that does not occur;
5. normalisation with the dataset's own grayscale statistics (mean 0.4932,
   std 0.2458, measured on 800 random **training** images after the resize);
   the single channel is passed through as `[1, H, W]` and never duplicated
   into RGB.

`image_size` is a config value, not a constant: 224 is what PulmoNet-7M is
sized for (five 2× reductions land on a 7×7 map) and the cheapest baseline;
320–384 preserves more detail for subtle infiltrates; 512+ is for the
localisation stage. Change it without touching code:

| Variable | Meaning | Default |
|---|---|---|
| `PULMOAI_IMAGE_SIZE` | network input size | `224` |
| `PULMOAI_IMAGE_CHANNELS` | must stay 1 (grayscale, PulmoNet input) | `1` |
| `PULMOAI_TRAIN_RATIO` / `PULMOAI_VAL_RATIO` / `PULMOAI_TEST_RATIO` | split ratios | `0.70 / 0.15 / 0.15` |
| `PULMOAI_SEED` | split seed | `42` |

---

## 7. Verifying the pipeline

Two entry points, both read-only, both decoding only a handful of images.

### Full pipeline in one command — `ai/src/data/smoke_test.py`

```powershell
ai\.venv\Scripts\python.exe ai\src\data\smoke_test.py
ai\.venv\Scripts\python.exe ai\src\data\smoke_test.py --samples 5 --batches 4 --batch-size 16
```

Five stages, exit code 0 only if every check passes:

1. **config/paths** — dataset root, images dir and annotation JSON resolve and
   exist; `dataset_mapping.csv`, `bounding_boxes.csv`, `dataset_split.csv` are
   present; the active `image_size` / `channels` / `seed` / ratios are printed;
2. **split statistics** — images, patients, positive/negative and positive rate
   per split; the split covers exactly the 29 684 labelled images, has no
   duplicated image and leaves the 316 unlabelled ones out;
3. **patient overlap** — explicit set intersections for train∩val, train∩test,
   val∩test, on both `patient_id` and `sop_instance_uid`;
4. **real samples** — `--samples` per class (Lung Opacity / Normal / No Lung
   Opacity / Not Normal). For each: `pixel_array` decodes, MONOCHROME1 comes
   out as the exact inverse of MONOCHROME2, the float image stays in [0, 1],
   the tensor has the configured shape/dtype and is finite, the label matches
   the class name, the box count matches `bounding_boxes.csv`, boxes are valid
   xyxy inside the frame, normalised boxes are in 0..1, and the scale factor
   from the 1024 frame is exact;
5. **DataLoader** — `--batches` batches: image/label shapes and dtypes, boxes
   preserved per image by `collate_samples` (including a batch with a differing
   number of boxes), boxes present exactly for positives, and a `tracemalloc`
   reading proving memory does not grow while iterating.

Current state: **107/107 checks pass** (peak Python-level memory during
iteration: 6 MB).

### Unit-style checks — `ai/src/data/test_dataset.py`

```powershell
ai\.venv\Scripts\python.exe ai\src\data\test_dataset.py
ai\.venv\Scripts\python.exe -m pytest ai/src/data/test_dataset.py -v   # if pytest is installed
```

Nine checks: the DICOM decodes, tensor shape and dtype are right, the label
matches the class name, a positive sample has at least one box inside the frame
with `x2 > x1`, a negative sample has none, several samples load in a row, the
DataLoader batches while keeping variable-length boxes, augmentation changes
pixels but not the label, rotation drops boxes that leave the frame, and the
three splits do not overlap. Current state: **9/9 pass**.

---




## 8. Model — PulmoNet-7M (custom CNN, from scratch)

One architecture for the whole project: a CNN written from basic PyTorch
layers. No torchvision model, no published backbone (DenseNet / ResNet /
EfficientNet / VGG), no pretrained weights, no transfer learning. Every
parameter starts from random (Kaiming) initialisation.

Input is a **single grayscale channel** — a radiograph has no colour, so the
plane goes into the network as it comes out of the DICOM and is never
duplicated into RGB.

```
Input  1 × 224 × 224
   ↓
Stem     Conv3×3 s2 (1→32)   + BN + ReLU              →  32 × 112 × 112
   ↓
Block 1  Conv3×3 (32→64)     + BN + ReLU
         Conv3×3 (64→64)     + BN + ReLU
         MaxPool 2×2                                  →  64 ×  56 ×  56
   ↓
Block 2  Conv3×3 (64→128)    + BN + ReLU
         Conv3×3 (128→128)   + BN + ReLU
         MaxPool 2×2                                  → 128 ×  28 ×  28
   ↓
Block 3  Conv3×3 (128→256)   + BN + ReLU
         Conv3×3 (256→256)   + BN + ReLU  × 2
         MaxPool 2×2  →  Dropout2d(0.1)               → 256 ×  14 ×  14
   ↓
Block 4  Conv3×3 (256→384)   + BN + ReLU
         Conv3×3 (384→384)   + BN + ReLU  × 2
         MaxPool 2×2  →  Dropout2d(0.1)               → 384 ×   7 ×   7
   ↓
Block 5  Conv3×3 (384→512)   + BN + ReLU              → 512 ×   7 ×   7
   ↓
AdaptiveAvgPool2d(1)                                  → 512
   ↓  Dropout(0.4)
Linear(512 → 1)                                       → [B] logits
```

Every convolution: 3×3, stride 1, padding 1, `bias=False` (the following
BatchNorm supplies the shift). The only stride-2 convolution is the stem.

### Parameters (counted with torch)

| Part | Parameters |
|---|---|
| stem | 352 |
| block1 | 55 552 |
| block2 | 221 696 |
| block3 | 1 476 096 |
| block4 | 3 541 248 |
| block5 | 1 770 496 |
| classifier | 513 |
| **total (all trainable)** | **7 065 953** |

28.3 MB fp32, ≈7.1 MB after int8 quantisation. 3.3 GMACs per image.

### Design rationale

| Decision | Reason |
|---|---|
| stride-2 stem | the 1024² source is already resized to 224²; halving immediately cuts compute 4× with no useful detail lost |
| 5 stages, 14 convolutions | 224 → 7 needs five 2× reductions; the depth grows the receptive field of the last layer to ≈265 px, i.e. larger than the frame, so the decision uses the whole radiograph — the adjudicated boxes reach 528×942 px in the 1024 frame, so wide context matters |
| widths 32→64→128→256→384→512 | halving the resolution while widening keeps per-stage cost roughly constant; the 384 step (instead of 512) is what fits the network into the ~7 M budget without dropping a layer |
| no residual connections | 14 layers with BatchNorm train from scratch without them; skip connections start paying off well past ~20 layers |
| BatchNorm after every conv | essential when training from scratch — stabilises the distributions, allows a higher LR, and adds mild regularisation |
| ReLU (not GELU) | cheaper, and it fuses with Conv+BN in int8 mobile runtimes; GELU expands into several ops in TFLite and often breaks that fusion |
| MaxPool (not strided conv) | costs no parameters (the budget is tight), picks the strongest local response, and exports cleanly |
| `Dropout2d` only in stages 3–4 | element-wise dropout is nearly useless between correlated conv activations; spatial dropout drops whole channels. Early blocks hold few parameters, so nothing to regularise there |
| GAP instead of Flatten + Linear | `Flatten(512×7×7)` = 25 088 features; a hidden layer on top would cost ~12.8 M parameters — more than the rest of the network — and would overfit 20 779 images while pinning the model to exactly 224×224. GAP costs 0 parameters, keeps the input size flexible, and leaves the 512×7×7 map directly usable for a CAM-style heatmap later (which the Flutter UI already has a slot for) |

Why ~7 M parameters for ~29.7 k images: ≈340 parameters per training image.
That looks over-parameterised on paper, but convolutional weights are shared
across every spatial position, so the effective capacity is far lower — CNNs of
this size are the normal choice at this data scale. Below ~3 M the mid-level
stages start to underfit at 224²; above ~15 M the extra capacity rarely pays
off without pretraining.

**Overfitting is the main expected risk**, since training runs from scratch on
20 779 images with 24 % positives. Countermeasures in place: augmentation
(±7° rotation, ±20 % brightness/contrast), BatchNorm, `Dropout2d(0.1)` in the
two deepest stages, `Dropout(0.4)` before the classifier, `pos_weight`, early
stopping on validation ROC-AUC, and an untouched test split. The train/val gap
in `history.csv` is the thing to watch during the first real run.

No claim is made here about diagnostic accuracy; this is an engineering
argument about capacity and compute, and the numbers will come from the
validation split.

### Mobile export

Only base operators are used — Conv2d, BatchNorm2d, ReLU, MaxPool2d,
AdaptiveAvgPool2d(1), Dropout (a no-op in eval), Linear — all covered by ONNX
opset 11+ and TFLite builtins. Conv+BN fold into a single convolution at export
(−22 layers at runtime). A single-channel input also means the mobile app can
feed the grayscale plane directly, with no RGB conversion step.

Code: `ai/src/models/pulmonet.py` (`PulmoNet`, `ModelConfig`, `build_model()`).

---
## 9. Training

```
ai/src/training/
├── __init__.py
├── losses.py          BCEWithLogitsLoss + compute_pos_weight (train split only)
├── metrics.py         accuracy / precision / recall / specificity / F1 / ROC-AUC / AUPRC
├── train.py           training + validation loop, best checkpoint, early stopping
├── evaluate.py        scores a checkpoint on a split — where the test set is used
├── pilot_run.py       overfits a tiny subset to prove the loss goes down
├── smoke_train.py     8-check wiring test on one batch
└── test_metrics.py    metric correctness vs the pairwise AUC definition
```

**Loss.** `BCEWithLogitsLoss(pos_weight = negatives / positives)`.
`compute_pos_weight` **refuses any split other than train** — asking for `val`
or `test` raises, so the held-out label balance cannot leak into the objective.
Current value: **3.1775** (15 805 / 4 974).

**Metrics.** Accuracy, precision, recall, specificity, F1, ROC-AUC, AUPRC and
the running loss, accumulated over a whole epoch (never averaged per batch — a
batch-level AUC is meaningless). ROC-AUC uses the Mann–Whitney rank identity
with averaged ranks for ties, verified against the brute-force pairwise
definition in `test_metrics.py` (exact to 1e-9).

**Checkpoints and early stopping.** After each epoch `last.pt` is refreshed;
`best.pt` is written whenever validation ROC-AUC improves by more than
`min_delta`. `ReduceLROnPlateau` (factor 0.5, patience 2) reacts to the same
metric, and training stops once it has not improved for
`--early-stopping` epochs (default 5).

**Experiment output** — `ai/experiments/<experiment_name>/` (git-ignored):

| File | Content |
|---|---|
| `config.json` | the full resolved configuration of the run |
| `history.csv` | one row per epoch: lr + every train and val metric |
| `best.pt` / `last.pt` | model + optimizer state, config, val metrics, pos_weight |
| `results.json` | best epoch, best val metrics, duration, early-stop flag; `evaluate.py` adds `test_metrics` |
| `metrics_test.json`, `predictions_test.csv` | written by `evaluate.py` (per-image probabilities, for ROC/PR curves) |

**The test split is never read by `train.py`.** It is scored once, afterwards,
by `evaluate.py` using the checkpoint chosen on validation ROC-AUC.

**Configuration** (`TrainingConfig` in `ai/src/config.py`, env var or CLI flag):

| Setting | Default | Env var | CLI |
|---|---|---|---|
| image size | 224 | `PULMOAI_IMAGE_SIZE` | — |
| batch size | 32 | `PULMOAI_BATCH_SIZE` | `--batch-size` |
| learning rate | 3e-4 | `PULMOAI_LR` | `--lr` |
| weight decay | 1e-4 | `PULMOAI_WEIGHT_DECAY` | `--weight-decay` |
| dropout (head) | 0.4 | `PULMOAI_DROPOUT` | `--dropout` |
| spatial dropout | 0.1 | `PULMOAI_SPATIAL_DROPOUT` | — |
| epochs | 30 | `PULMOAI_EPOCHS` | `--epochs` |
| early stopping patience | 5 | `PULMOAI_EARLY_STOPPING` | `--early-stopping` |
| seed | 42 | `PULMOAI_SEED` | `--seed` |
| dataloader workers | 8 | `PULMOAI_NUM_WORKERS` | `--num-workers` |
| experiments dir | `ai/experiments` | `PULMOAI_EXPERIMENTS_DIR` | — |
| experiment name | pulmonet7m-scratch | `PULMOAI_EXPERIMENT` | `--experiment` |

Optimiser: AdamW at 3e-4 with weight decay 1e-4 — a higher learning rate
than a fine-tuning run would use (the network starts from random weights)
and stronger decay, since overfitting is the main risk when training from
scratch on 20 779 images.

### Pre-flight checks (run these, in this order)

```powershell
ai\.venv\Scripts\python.exe ai\src\training\test_metrics.py     # metrics, no data needed
ai\.venv\Scripts\python.exe ai\src\training\smoke_train.py      # 1 batch: fwd/loss/bwd/step
ai\.venv\Scripts\python.exe ai\src\training\pilot_run.py        # does the loss go down?
```

`smoke_train.py` — model builds, a real batch loads from DICOM, forward shape,
finite logits, finite scalar loss, finite gradients, the optimizer step moves
the classifier weights, the loss is still finite afterwards, metrics compute.
~3 s, no checkpoint. Current state: **8/8 pass**.

`pilot_run.py` — overfits a fixed 32-image subset (`--batches`, `--batch-size`,
`--epochs`, `--lr`) and asserts the loss actually falls. A randomly initialised
network that cannot fit 32 images has a broken pipeline. ~18 s on CPU, nothing
saved, val/test never touched. Current state: **3/3 pass**, loss
1.1366 → 0.0799 over 6 passes.

### Full training (needs explicit confirmation — not started)

```powershell
ai\.venv\Scripts\python.exe ai\src\training\train.py --epochs 30
ai\.venv\Scripts\python.exe ai\src\training\train.py --max-batches 2 --epochs 1   # wiring only
```

Then, once the best checkpoint exists:

```powershell
ai\.venv\Scripts\python.exe ai\src\training\evaluate.py --split test
```

Hardware note: `torch 2.10.0+cu130` on an RTX 5070 Ti (sm_120). Measured:
PulmoNet-7M forward+backward is **29.7 ms at batch 32** (1.19 GiB) and 59.9 ms
at batch 64 (2.24 GiB) — about **19 s of GPU time per epoch**. The bottleneck
is data loading, not the network: decoding one JPEG-compressed DICOM plus the
resize takes ~35 ms on one core, i.e. ~12 minutes per epoch at
`num_workers=0`. The default is therefore **`num_workers=8`**, measured at
5.0 ms/image in steady state — roughly **1.7 minutes per epoch**, so a
30-epoch run lands near an hour.

---
## 10. Known issues and notes

* **Pixel data is JPEG-compressed** — transfer syntax `1.2.840.10008.1.2.4.50`
  (JPEG Baseline, Process 1) for all 30 000 files, so `pydicom` alone cannot
  decode it. `pylibjpeg` + `pylibjpeg-libjpeg` are required (both in
  `requirements.txt`); without them `pixel_array` raises. The transfer syntax is
  now recorded per file in `dataset_mapping.csv`.
* Lossy JPEG means the pixels are already degraded relative to the original NIH
  PNGs — nothing to fix, but worth stating in the thesis.
* Class imbalance: 24 % positive. Use `pos_weight` (3.18) or a balanced sampler,
  and report AUPRC next to AUROC.
* `PatientID` is 1:1 with the study here, so patient-level and image-level
  splits coincide — do not read "0 leaked patients" as proof that grouping was
  actually exercised.
* The 316 unlabelled images remain in the mapping; anything reading it directly
  must filter `matched == 1` (the Dataset does).
* Console encoding: the scripts force UTF-8 on stdout where possible — a
  cp1251 Windows console cannot print characters such as U+2229, which broke
  the first smoke-test run.
* Data loading, not the network, sets the epoch time: ~35 ms per image on one
  core (JPEG DICOM decode + resize) against ~19 s of GPU time per epoch. With
  the default 8 workers it drops to 5.0 ms/image (~1.7 min/epoch).
* Training a custom CNN from scratch (no pretrained initialisation of any
  kind) converges slower than a pretrained baseline would; that is a
  deliberate constraint of this project, and 20 779 images is on the small
  side for it. Watch the train/val gap in `history.csv`.
* The grayscale mean/std in `PreprocessConfig` were re-measured for the
  1-channel pipeline (0.4932 / 0.2458 on 800 training images). If
  `image_size` changes, they stay valid — they are computed after the resize
  and the resize is area-preserving in the mean.
* Not started yet: the actual training run, evaluation on the test split, and
  the mobile export for the Flutter app.
