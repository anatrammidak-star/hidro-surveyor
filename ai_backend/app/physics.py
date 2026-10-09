GRAVITY = 9.81
WATER_DENSITY = 1000.0


def calculate_discharge(
    width_m: float,
    depth_m: float,
    velocity_mps: float,
    area_factor: float = 0.75,
) -> float:
    if width_m <= 0 or depth_m <= 0 or velocity_mps < 0:
        raise ValueError("Dimensi sungai harus positif dan kecepatan tidak negatif.")

    area = width_m * depth_m * area_factor
    return area * velocity_mps


def calculate_net_head(
    gross_head_m: float,
    head_loss_factor: float = 0.90,
) -> float:
    if gross_head_m < 0:
        raise ValueError("Head bruto tidak boleh negatif.")

    if not 0 < head_loss_factor <= 1:
        raise ValueError("Faktor kehilangan head harus antara 0 dan 1.")

    return gross_head_m * head_loss_factor


def calculate_power_kw(
    discharge_cms: float,
    net_head_m: float,
    efficiency: float = 0.70,
) -> float:
    if discharge_cms < 0 or net_head_m < 0:
        raise ValueError("Debit dan head tidak boleh negatif.")

    if not 0 < efficiency <= 1:
        raise ValueError("Efisiensi harus lebih dari 0 hingga 1.")

    return (
        WATER_DENSITY
        * GRAVITY
        * discharge_cms
        * net_head_m
        * efficiency
        / 1000
    )
