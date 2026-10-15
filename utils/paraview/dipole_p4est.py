# Inspect the adaptive element mesh throughout the 3D dipole simulation.
# Run from the package root after the two README conversion commands:
#   paraview --script=utils/paraview/dipole_p4est.py
# Optional: DIPOLE_PVD, DIPOLE_MESH_PVD, PV_TIME and PV_SCREENSHOT.
import os

from paraview.simple import *
from paraview import servermanager


def collection(variable, default):
    path = os.path.abspath(os.environ.get(variable, default))
    if not os.path.isfile(path):
        raise FileNotFoundError(path + "; run the elixir/conversion in the README first")
    reader = PVDReader(registrationName=os.path.basename(path), FileName=path)
    reader.UpdatePipelineInformation()
    return reader


reader = collection("DIPOLE_PVD", "out/vtk/dipole.pvd")
mesh = collection("DIPOLE_MESH_PVD", "out/vtk_mesh/dipole_celldata.pvd")
if list(reader.TimestepValues) != list(mesh.TimestepValues):
    raise RuntimeError("Field and mesh collections must contain the same timesteps")

view = GetActiveViewOrCreate("RenderView")
view.Background = [1.0, 1.0, 1.0]
view.UseColorPaletteForBackground = 0
view.ViewSize = [1000, 800]

# Keep whole elements in one half of the domain to expose the interior mesh.
# Use geometry rather than the converter's unreliable 3D refinement-level data.
mesh_clip = Clip(registrationName="half-domain adaptive elements", Input=mesh)
mesh_clip.ClipType = "Plane"
mesh_clip.ClipType.Origin = [0.0, 1e-6, 0.0]
mesh_clip.ClipType.Normal = [0.0, 1.0, 0.0]
mesh_clip.Invert = 1
mesh_clip.Crinkleclip = 1
mesh_display = Show(mesh_clip, view)
mesh_display.Representation = "Wireframe"
mesh_display.ColorArrayName = ["POINTS", ""]
mesh_display.DiffuseColor = [0.15, 0.15, 0.15]
mesh_display.AmbientColor = [0.15, 0.15, 0.15]
mesh_display.Opacity = 0.3

# A small offset avoids a cut coincident with internal Cartesian faces.
plane = Slice(registrationName="Hy slice near y = 0", Input=reader)
plane.SliceType = "Plane"
plane.SliceType.Origin = [0.0, 1e-6, 0.0]
plane.SliceType.Normal = [0.0, 1.0, 0.0]
field_display = Show(plane, view)
# Set the coloring directly without an automatic data-range lookup.
field_display.SetScalarColoring("Hy", servermanager.GetAssociationFromString("POINTS"))
lut = GetColorTransferFunction("Hy")
lut.ApplyPreset("Cool to Warm", True)
lut.AutomaticRescaleRangeMode = "Never"
lut.RescaleTransferFunction(-1.0, 1.0)
field_display.SetScalarBarVisibility(view, True)
bar = GetScalarBar(lut, view)
bar.Title = "Hy"
bar.ComponentTitle = ""
bar.TitleColor = [0.1, 0.1, 0.1]
bar.LabelColor = [0.1, 0.1, 0.1]

outline = Outline(Input=reader)
outline_display = Show(outline, view)
outline_display.ColorArrayName = ["POINTS", ""]
outline_display.DiffuseColor = [0.3, 0.3, 0.3]

title = Text(registrationName="title")
title.Text = "Adaptive element mesh and Hy slice"
title_display = Show(title, view)
title_display.WindowLocation = "Upper Left Corner"
title_display.Color = [0.1, 0.1, 0.1]
time = AnnotateTimeFilter()
time.Format = "t = {time:.2f}"
time_display = Show(time, view)
time_display.WindowLocation = "Lower Left Corner"
time_display.Color = [0.1, 0.1, 0.1]

scene = GetAnimationScene()
scene.UpdateAnimationUsingDataTimeSteps()
times = list(reader.TimestepValues)
requested = os.environ.get("PV_TIME")
scene.AnimationTime = (times[0] if requested is None else
                       min(times, key=lambda t: abs(t - float(requested))))
view.ViewTime = scene.AnimationTime
view.CameraPosition = [4.0, -6.0, 3.0]
view.CameraFocalPoint = [0.0, 0.0, 0.0]
view.CameraViewUp = [0.0, 0.0, 1.0]
view.ResetCamera(False)
SetActiveView(view)
Render()
if os.environ.get("PV_SCREENSHOT"):
    SaveScreenshot(os.path.abspath(os.environ["PV_SCREENSHOT"]), view,
                   ImageResolution=[1000, 800])
