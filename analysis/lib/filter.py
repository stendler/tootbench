"""
Collection of filter functions to be used on pandas DataFrames.
"""

from typing import Callable

from pandas import DataFrame


def none(df: DataFrame) -> DataFrame:
    return df


def of(*args: (Callable[[DataFrame], DataFrame])) -> Callable[[DataFrame], DataFrame]:
    def iter_filter(df: DataFrame) -> DataFrame:
        ret = df
        for filter in args:
            ret = filter(ret)
        return ret
    return iter_filter


def either(column: str, *args) -> Callable[[DataFrame], DataFrame]:
    def condition_iter(df: DataFrame) -> DataFrame:
        cond = None
        for value in args:
            if cond is None:
                cond = df[column] == value
            else:
                cond |= df[column] == value
        return df[cond]
    return condition_iter


def client(df: DataFrame) -> DataFrame:
    return df[df["host"] == "client"]


def instances(df: DataFrame) -> DataFrame:
    return df[df["host"] != "client"]


def scenario(name: str) -> Callable[[DataFrame], DataFrame]:
    return column("scenario", name)


def scenarios(*args: (str)) -> Callable[[DataFrame], DataFrame]:
    return either("scenario", *args)


def run(name: str = "1") -> Callable[[DataFrame], DataFrame]:
    return column("run", name)


def column(column: str, value: str) -> Callable[[DataFrame], DataFrame]:
    def column_filter(df: DataFrame) -> DataFrame:
        return df[df[column] == value]
    return column_filter



