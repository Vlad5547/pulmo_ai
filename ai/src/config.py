"""Central configuration for the PulmoAI research code.

Every path used by the AI pipeline is resolved here, so the dataset location
is never hard-coded in more than one place.

Resolution order for each setting (first hit wins):

1. an environment variable;
2. a ``KEY=value`` line in ``ai/.env`` (optional, git-ignored);
3. the default below.

Environment variables
---------------------
PULMOAI_DATASET_ROOT   root of the RSNA dataset (contains ``images/`` and the
                       annotation JSON)
PULMOAI_IMAGES_DIR     override the DICOM root if it is not ``<root>/images``
PULMOAI_ANNOTATIONS    override the annotation JSON path
PULMOAI_PROCESSED_DIR  where derived artefacts (mapping files) are written
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

# ai/src/config.py -> ai/
AI_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = AI_ROOT.parent
ENV_FILE = AI_ROOT / ".env"

DEFAULT_DATASET_ROOT = Path(r"D:\datasets\pneumonia_dataset_2018")

# The adjudicated export is an MD.ai project file; the name is matched by glob
# so a differently named export in the same folder still works.
ANNOTATION_GLOB = "*annotations*.json"


def _load_env_file(path: Path) -> dict[str, str]:
    """Minimal ``.env`` reader (no external dependency)."""
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


_ENV_FILE_VALUES = _load_env_file(ENV_FILE)


def setting(name: str, default: str | None = None) -> str | None:
    return os.environ.get(name) or _ENV_FILE_VALUES.get(name) or default


@dataclass(frozen=True)
class DatasetPaths:
    """Filesystem layout of the RSNA Pneumonia Detection Challenge dataset."""

    root: Path
    images_dir: Path
    annotations_file: Path
    processed_dir: Path

    def validate(self) -> None:
        if not self.root.is_dir():
            raise FileNotFoundError(
                f"Dataset root not found: {self.root}\n"
                "Set PULMOAI_DATASET_ROOT (environment variable or ai/.env)."
            )
        if not self.images_dir.is_dir():
            raise FileNotFoundError(f"DICOM directory not found: {self.images_dir}")
        if not self.annotations_file.is_file():
            raise FileNotFoundError(
                f"Annotation JSON not found: {self.annotations_file}"
            )


def _resolve_annotations(root: Path) -> Path:
    explicit = setting("PULMOAI_ANNOTATIONS")
    if explicit:
        return Path(explicit)
    matches = sorted(root.glob(ANNOTATION_GLOB))
    if matches:
        return matches[0]
    return root / "pneumonia-challenge-annotations-adjudicated-kaggle_2018.json"


def get_dataset_paths() -> DatasetPaths:
    root = Path(setting("PULMOAI_DATASET_ROOT", str(DEFAULT_DATASET_ROOT)))
    images_dir = Path(setting("PULMOAI_IMAGES_DIR", str(root / "images")))
    processed_dir = Path(
        setting("PULMOAI_PROCESSED_DIR", str(AI_ROOT / "data" / "processed"))
    )
    return DatasetPaths(
        root=root,
        images_dir=images_dir,
        annotations_file=_resolve_annotations(root),
        processed_dir=processed_dir,
    )


# ---------------------------------------------------------------------------
# Annotation semantics (verified against the actual export, see ai/README.md)
# ---------------------------------------------------------------------------

# MD.ai label group holding the final, adjudicated ground truth. The per-team
# groups ("Team 1", "Team 2", "Team 2a", "Adjudication", "QA") are the raw
# reader annotations that this group was derived from.
GROUND_TRUTH_GROUP = "Calculated"

CLASS_LUNG_OPACITY = "Lung Opacity"
CLASS_NORMAL = "Normal"
CLASS_NOT_NORMAL = "No Lung Opacity / Not Normal"

GROUND_TRUTH_CLASSES = (CLASS_LUNG_OPACITY, CLASS_NORMAL, CLASS_NOT_NORMAL)

# Binary task: only "Lung Opacity" is positive. Both remaining adjudicated
# classes are negative — that is the RSNA challenge definition.
POSITIVE_CLASSES = (CLASS_LUNG_OPACITY,)
NEGATIVE_CLASSES = (CLASS_NORMAL, CLASS_NOT_NORMAL)


# ---------------------------------------------------------------------------
# Derived artefacts produced by the data scripts
# ---------------------------------------------------------------------------

MAPPING_CSV = "dataset_mapping.csv"
BOXES_CSV = "bounding_boxes.csv"
SUMMARY_JSON = "dataset_summary.json"
SPLIT_CSV = "dataset_split.csv"
SPLIT_SUMMARY_JSON = "split_summary.json"


# ---------------------------------------------------------------------------
# Preprocessing / split configuration
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class PreprocessConfig:
    """Image pipeline settings.

    ``image_size`` is deliberately a setting rather than a magic number. The
    source images are 1024x1024, 8-bit, MONOCHROME2. Reasonable choices:

    * 224 - the input PulmoNet-7M was sized for (five 2x downsamplings land on
      a 7x7 feature map); the cheapest baseline;
    * 320/384 - keeps more detail for subtle infiltrates, common in RSNA
      challenge solutions;
    * 512+ - for the detection/localisation stage, where small opacities
      matter.

    Override with PULMOAI_IMAGE_SIZE without touching code.
    """

    image_size: int = 224
    # Chest radiographs are grayscale and PulmoNet takes a single channel:
    # the plane is never duplicated into RGB.
    channels: int = 1
    # Measured on 800 random training images after the 1024 -> 224 resize
    # (see ai/README.md section 6); train split only, never val/test.
    grayscale_mean: float = 0.4932
    grayscale_std: float = 0.2458
    # Train-time augmentation (kept intentionally mild for radiographs).
    random_horizontal_flip: float = 0.0  # off: left/right anatomy is meaningful
    random_brightness_contrast: float = 0.2
    max_rotation_degrees: float = 7.0


@dataclass(frozen=True)
class SplitConfig:
    """Train/validation/test split settings."""

    train_ratio: float = 0.70
    val_ratio: float = 0.15
    test_ratio: float = 0.15
    seed: int = 42
    # Column that identifies a patient. Verified 1:1 with StudyInstanceUID in
    # this dataset, but grouping is applied anyway so the split stays correct
    # if more images per patient are ever added.
    group_column: str = "patient_id"
    stratify_column: str = "target"

    def validate(self) -> None:
        total = self.train_ratio + self.val_ratio + self.test_ratio
        if abs(total - 1.0) > 1e-6:
            raise ValueError(f"Split ratios must sum to 1.0, got {total}")


def get_preprocess_config() -> PreprocessConfig:
    return PreprocessConfig(
        image_size=int(setting("PULMOAI_IMAGE_SIZE", "224")),
        channels=int(setting("PULMOAI_IMAGE_CHANNELS", "1")),
    )


def get_split_config() -> SplitConfig:
    config = SplitConfig(
        train_ratio=float(setting("PULMOAI_TRAIN_RATIO", "0.70")),
        val_ratio=float(setting("PULMOAI_VAL_RATIO", "0.15")),
        test_ratio=float(setting("PULMOAI_TEST_RATIO", "0.15")),
        seed=int(setting("PULMOAI_SEED", "42")),
    )
    config.validate()
    return config
# ---------------------------------------------------------------------------
# Experiment / training configuration
# ---------------------------------------------------------------------------

# One architecture for the whole project: PulmoNet-7M, a custom CNN built from
# basic PyTorch layers and trained from scratch. No pretrained weights are
# downloaded anywhere in this repository, and no alternative backbone exists.
MODEL_NAME = "pulmonet7m"

EXPERIMENTS_DIR_DEFAULT = AI_ROOT / "experiments"


@dataclass(frozen=True)
class TrainingConfig:
    """Everything one experiment needs, in one object.

    Overridable per field through environment variables / ``ai/.env`` (see
    :func:`get_training_config`) or CLI flags on ``train.py``.
    """

    # data
    image_size: int = 224
    channels: int = 1  # grayscale
    batch_size: int = 32
    # 8 workers: decoding one JPEG-compressed DICOM takes ~35 ms on a single
    # core, so with 0 workers the GPU would idle ~97 % of the time.
    num_workers: int = 8

    # model (architecture is fixed; only the head regularisation is tunable)
    dropout: float = 0.4
    spatial_dropout: float = 0.1

    # optimisation (tuned for training from scratch: a higher LR than a
    # fine-tuning run would use, and stronger decay against overfitting)
    learning_rate: float = 3e-4
    weight_decay: float = 1e-4
    epochs: int = 30
    seed: int = 42
    # class imbalance: computed from TRAIN only, never from val/test
    use_pos_weight: bool = True
    # ReduceLROnPlateau on the monitored validation metric
    scheduler_factor: float = 0.5
    scheduler_patience: int = 2
    # stop when the monitored metric has not improved for this many epochs
    early_stopping_patience: int = 5
    min_delta: float = 1e-4

    # bookkeeping
    experiments_dir: Path = EXPERIMENTS_DIR_DEFAULT
    experiment_name: str = "pulmonet7m-scratch"
    monitor_metric: str = "roc_auc"  # best checkpoint is chosen on this

    @property
    def model_name(self) -> str:
        return MODEL_NAME

    @property
    def run_dir(self) -> Path:
        return self.experiments_dir / self.experiment_name


def get_training_config() -> TrainingConfig:
    preprocess = get_preprocess_config()
    return TrainingConfig(
        image_size=preprocess.image_size,
        channels=preprocess.channels,
        batch_size=int(setting("PULMOAI_BATCH_SIZE", "32")),
        num_workers=int(setting("PULMOAI_NUM_WORKERS", "8")),
        dropout=float(setting("PULMOAI_DROPOUT", "0.4")),
        spatial_dropout=float(setting("PULMOAI_SPATIAL_DROPOUT", "0.1")),
        learning_rate=float(setting("PULMOAI_LR", "3e-4")),
        weight_decay=float(setting("PULMOAI_WEIGHT_DECAY", "1e-4")),
        epochs=int(setting("PULMOAI_EPOCHS", "30")),
        seed=int(setting("PULMOAI_SEED", "42")),
        early_stopping_patience=int(setting("PULMOAI_EARLY_STOPPING", "5")),
        experiments_dir=Path(
            setting("PULMOAI_EXPERIMENTS_DIR", str(EXPERIMENTS_DIR_DEFAULT))
        ),
        experiment_name=setting("PULMOAI_EXPERIMENT", "pulmonet7m-scratch"),
    )
