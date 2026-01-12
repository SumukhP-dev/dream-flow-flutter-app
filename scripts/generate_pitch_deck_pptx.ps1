Param(
  [string]$In = "docs/pitch_deck/pitch_deck_slides.json",
  [string]$Out = "docs/pitch_deck/dream-flow-pitch-deck.pptx"
)

$ErrorActionPreference = "Stop"

Write-Host "Installing pitch deck generator deps..."
python -m pip install -r scripts/requirements-pitch-deck.txt | Out-Host

Write-Host "Generating PPTX..."
python scripts/generate_pitch_deck_pptx.py --in $In --out $Out | Out-Host

Write-Host "Done. Output: $Out"

