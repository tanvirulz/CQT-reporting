#!/usr/bin/env bash
set -e

##############################
# Default Configuration
##############################

calibration_right="${calibration_right:-2447f0fad33dfea493b4e7bc4143c8bd2e28d979}"
RUNID_RIGHT="${RUNID_RIGHT:-20251108115234}"

calibration_left="${calibration_left:-1e1f7e1d1af58009eda1986bb3689e6b9b2356b6}"
RUNID_LEFT="${RUNID_LEFT:-20251123023814}"

PYTHON=".venv/bin/python"   # ensures uv environment is used
LATEX="pdflatex"
DATESTAMP=$(date +%d%m%Y_%H)

##############################
# Helper: ensure venv exists
##############################

ensure_venv() {
    if [ ! -f ".venv/bin/python" ]; then
        echo "No uv environment detected. Running uv sync..."
        uv sync
    fi
}

##############################
# Download commands
##############################

download_latest_two() {
    mkdir -p data
    echo "Downloading latest two experiments..."
    $PYTHON download.py --latest-two
}

download_data() {
    mkdir -p data
    echo "Downloading data for experiment $calibration_left"
    $PYTHON download.py --hash-id "$calibration_left" --run-id "$RUNID_LEFT"

    echo "Downloading data for experiment $calibration_right"
    $PYTHON download.py --hash-id "$calibration_right" --run-id "$RUNID_RIGHT"
}

##############################
# Build report
##############################

clean() {
    echo "Cleaning build directory..."
    rm -rf build/*
}

build() {
    ensure_venv
    clean
    mkdir -p build
    cp src/templates/placeholder.png build/placeholder.png

    echo "Building LaTeX report..."
    $PYTHON src/main.py \
        --calibration-left "$calibration_left" \
        --calibration-right "$calibration_right" \
        --run-left "$RUNID_LEFT" \
        --run-right "$RUNID_RIGHT" \
        --no-tomography-plot
}

##############################
# Compile LaTeX to PDF
##############################

pdf_only() {
    echo "Compiling LaTeX to PDF..."
    mkdir -p logs

    $LATEX -output-directory=build report.tex > logs/pdflatex.log

    cp build/report.pdf .
    cp build/report.pdf "reports/report_${calibration_left:0:10}_vs_${calibration_right:0:10}_${DATESTAMP}.pdf"
    cp build/report.pdf reports/latest_report.pdf

    echo "PDF generated."
}

pdf() {
    build
    pdf_only
}

##############################
# Batch functions
##############################

batch_runscripts_numpy() {
    echo "Submitting sbatch job for device=numpy..."
    sbatch scripts/runscripts_numpy.sh
}

batch_runscripts_sinq20() {
    echo "Submitting sbatch job for device=sinq20..."
    sbatch scripts/runscripts_sinq20.sh
}

all() {
    batch_runscripts_numpy
    batch_runscripts_sinq20
    pdf
}

##############################
# Command-line interface
##############################

case "$1" in
    download-latest-two) download_latest_two ;;
    download-data)       download_data ;;
    clean)               clean ;;
    build)               build ;;
    pdf-only)            pdf_only ;;
    pdf)                 pdf ;;
    batch-runscripts-numpy) batch_runscripts_numpy ;;
    batch-runscripts-sinq20) batch_runscripts_sinq20 ;;
    all)                 all ;;
    *)
        echo "Usage: $0 {download-latest-two|download-data|clean|build|pdf-only|pdf|batch-runscripts-numpy|batch-runscripts-sinq20|all}"
        exit 1
        ;;
esac
