# Approved AutoMotors icon

The canonical image is automotors_app_icon.png: the original 1024 x 1024 RGB PNG
chosen by the owner in the conversation "Generar icono app coche", downloaded as
AutoMotors_icono_iPhone_1024.png. It shows Audi, BMW, Mercedes-Benz, Volkswagen
and Porsche vehicles under the silver and gold AutoMotors name.

Preserve this original artwork. The login and header brand mark use BoxFit.contain
inside a square; do not stretch the image or crop it with BoxFit.cover.

Generate the existing iOS and web exports with:
    python tool/export_brand_icons.py

Verify dimensions, opaque RGB encoding and exact exported pixels with:
    python tool/export_brand_icons.py --check

Pillow is required for these build-time exports.

Source SHA-256: 092fa781d549875b14a0b47602ed74bdb68ba3fb057560efd29e79c282a24a78
