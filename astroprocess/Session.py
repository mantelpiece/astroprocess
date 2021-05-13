
class Session:
    target: str
    date: str
    lights: List[SubframeGroup]
    reject_subframes: List[SubframeGroup]
    callibration_frames: CallibrationFrameSet

