# -*- coding: utf-8 -*-

"""
Copyright © 2019-present Lenovo

This file is licensed under both the BSD-3 license for individual use and
EPL-1.0 license for commercial use. Full text of both licenses can be found in
COPYING.BSD and COPYING.EPL files.
"""


class BackendDataBase(dict):
    def __getattr__(self, key):
        return self.get(key, None)


class BackendUser(BackendDataBase):
    pass


class BackendGroup(BackendDataBase):
    pass
