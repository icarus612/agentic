# Goal
Define data structures using modern Python 3.10+ standards.

# Instructions
1. If the data is internal only: Use `@dataclass(slots=True)`.
2. If the data crosses an API boundary (JSON): Use `pydantic.BaseModel`.
3. Always include docstrings for fields describing the units (e.g., "distance in meters").