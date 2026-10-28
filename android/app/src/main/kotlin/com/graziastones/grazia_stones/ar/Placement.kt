package com.graziastones.grazia_stones.ar

/**
 * Where a placed wall's position and size came from. The AR screen shows the scale tier to the user, so an
 * approximate surface is never presented as a measured one.
 *
 * Surface tags are what [ARCoreManager.placeWallAtScreenPoint] and friends record for a placement.
 */
object Placement {
    enum class Scale { MEASURED, USER, APPROXIMATE }

    fun provenance(surface: String?): String = when (surface) {
        null -> "none"
        "Plane", "wall_extended" -> "real_plane"
        // Base point on a tracked floor plane (metric); the wall faces the camera.
        "floor_line" -> "real_floor"
        // Tracked floor plane + the wall's own floor line in the image (metric distance and real angle).
        "edge_floor_tracked" -> "floor_edge"
        "DepthPoint" -> "validated_depth"
        "Point", "pointcloud" -> "validated_pointcloud"
        // "user_rectangle": four tapped corners of something the user measured (a painting, a door).
        "user_calibrated", "user_rectangle" -> "user_calibrated"
        // An A4 sheet found on the wall: its known 210 x 297 mm corners fix distance and angle (A4Reference).
        "a4_reference" -> "reference_object"
        // "approximate", and edge placements whose height had to be assumed ("edge_floor_assumed",
        // "edge_ceiling"): the wall's angle is real, its distance is not.
        else -> "approximate"
    }

    fun scale(surface: String?): Scale = when (provenance(surface)) {
        "user_calibrated" -> Scale.USER
        "approximate", "none" -> Scale.APPROXIMATE
        else -> Scale.MEASURED
    }

    /** May an automatic re-placement replace this one? Measured and user-calibrated placements are kept. */
    fun upgradable(surface: String?): Boolean = scale(surface) == Scale.APPROXIMATE && surface != null
}
