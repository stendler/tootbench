from typing import Callable

import numpy as np
import pandas as pd
from pandas import DataFrame


def mean(df_group: pd.core.groupby.GroupBy) -> DataFrame:
    return df_group.mean()


def max(df_group: pd.core.groupby.GroupBy) -> DataFrame:
    return df_group.max()


def tumble(columns: [str] = ["scenario", "run", "host"], time_column: str = "time", unit: str = "s", freq: str = "5s", new_unit: str = None, func: Callable[[pd.core.groupby.GroupBy], DataFrame] = mean) -> Callable[[DataFrame], DataFrame]:
    if new_unit is None:
        new_unit = unit
    def tumbling_window(df: DataFrame) -> DataFrame:
        ret_df = df.copy()
        # first turn the time_column in to a datetime64
        ret_df.loc[:, time_column] = pd.to_timedelta(ret_df[time_column], unit=unit)
        print(len(ret_df[time_column]))
        ret_df = func(ret_df.groupby(by=[pd.Grouper(key=time_column, freq=freq)] + columns)).reset_index()
        # switch back to
        ret_df[time_column] = (ret_df[time_column] / np.timedelta64(1, new_unit)).astype(np.float64)
        print(len(ret_df[time_column]))
        return ret_df
    return tumbling_window
