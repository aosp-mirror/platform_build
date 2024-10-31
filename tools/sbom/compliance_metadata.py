#!/usr/bin/env python3
#
# Copyright (C) 2024 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import sqlite3

class MetadataDb:
  def __init__(self, db):
    self.conn = sqlite3.connect(':memory')
    self.conn.row_factory = sqlite3.Row
    with sqlite3.connect(db) as c:
      c.backup(self.conn)
    self.reorg()

  def reorg(self):
    # package_license table
    self.conn.execute("create table package_license as "
                      "select name as package, pkg_default_applicable_licenses as license "
                      "from modules "
                      "where module_type = 'package' ")
    cursor = self.conn.execute("select package,license from package_license where license like '% %'")
    multi_licenses_packages = cursor.fetchall()
    cursor.close()
    rows = []
    for p in multi_licenses_packages:
      licenses = p['license'].strip().split(' ')
      for lic in licenses:
        rows.append((p['package'], lic))
    self.conn.executemany('insert into package_license values (?, ?)', rows)
    self.conn.commit()

    self.conn.execute("delete from package_license where license like '% %'")
    self.conn.commit()

    # module_license table
    self.conn.execute("create table module_license as "
                      "select distinct name as module, package, licenses as license "
                      "from modules "
                      "where licenses != '' ")
    cursor = self.conn.execute("select module,package,license from module_license where license like '% %'")
    multi_licenses_modules = cursor.fetchall()
    cursor.close()
    rows = []
    for m in multi_licenses_modules:
      licenses = m['license'].strip().split(' ')
      for lic in licenses:
        rows.append((m['module'], m['package'],lic))
    self.conn.executemany('insert into module_license values (?, ?, ?)', rows)
    self.conn.commit()

    self.conn.execute("delete from module_license where license like '% %'")
    self.conn.commit()

    # module_installed_file table
    self.conn.execute("create table module_installed_file as "
                      "select id as module_id, name as module_name, package, installed_files as installed_file "
                      "from modules "
                      "where installed_files != '' ")
    cursor = self.conn.execute("select module_id, module_name, package, installed_file "
                               "from module_installed_file where installed_file like '% %'")
    multi_installed_file_modules = cursor.fetchall()
    cursor.close()
    rows = []
    for m in multi_installed_file_modules:
      installed_files = m['installed_file'].strip().split(' ')
      for f in installed_files:
        rows.append((m['module_id'], m['module_name'], m['package'], f))
    self.conn.executemany('insert into module_installed_file values (?, ?, ?, ?)', rows)
    self.conn.commit()

    self.conn.execute("delete from module_installed_file where installed_file like '% %'")
    self.conn.commit()

    # module_built_file table
    self.conn.execute("create table module_built_file as "
                      "select id as module_id, name as module_name, package, built_files as built_file "
                      "from modules "
                      "where built_files != '' ")
    cursor = self.conn.execute("select module_id, module_name, package, built_file "
                               "from module_built_file where built_file like '% %'")
    multi_built_file_modules = cursor.fetchall()
    cursor.close()
    rows = []
    for m in multi_built_file_modules:
      built_files = m['installed_file'].strip().split(' ')
      for f in built_files:
        rows.append((m['module_id'], m['module_name'], m['package'], f))
    self.conn.executemany('insert into module_built_file values (?, ?, ?, ?)', rows)
    self.conn.commit()

    self.conn.execute("delete from module_built_file where built_file like '% %'")
    self.conn.commit()


    # Indexes
    self.conn.execute('create index idx_modules_id on modules (id)')
    self.conn.execute('create index idx_modules_name on modules (name)')
    self.conn.execute('create index idx_package_licnese_package on package_license (package)')
    self.conn.execute('create index idx_package_licnese_license on package_license (license)')
    self.conn.execute('create index idx_module_licnese_module on module_license (module)')
    self.conn.execute('create index idx_module_licnese_license on module_license (license)')
    self.conn.execute('create index idx_module_installed_file_module_id on module_installed_file (module_id)')
    self.conn.execute('create index idx_module_installed_file_installed_file on module_installed_file (installed_file)')
    self.conn.execute('create index idx_module_built_file_module_id on module_built_file (module_id)')
    self.conn.execute('create index idx_module_built_file_built_file on module_built_file (built_file)')
    self.conn.commit()

  def dump_debug_db(self, debug_db):
    with sqlite3.connect(debug_db) as c:
      self.conn.backup(c)

  def get_installed_files(self):
    # Get all records from table make_metadata, which contains all installed files and corresponding make modules' metadata
    cursor = self.conn.execute('select installed_file, module_path, is_prebuilt_make_module, product_copy_files, kernel_module_copy_files, is_platform_generated, license_text from make_metadata')
    rows = cursor.fetchall()
    cursor.close()
    installed_files_metadata = []
    for row in rows:
      metadata = dict(zip(row.keys(), row))
      installed_files_metadata.append(metadata)
    return installed_files_metadata

  def get_soong_modules(self):
    # Get all records from table modules, which contains metadata of all soong modules
    cursor = self.conn.execute('select name, package, package as module_path, module_type as soong_module_type, built_files, installed_files, static_dep_files, whole_static_dep_files from modules')
    rows = cursor.fetchall()
    cursor.close()
    soong_modules = []
    for row in rows:
      soong_module = dict(zip(row.keys(), row))
      soong_modules.append(soong_module)
    return soong_modules

  def get_package_licenses(self, package):
    cursor = self.conn.execute('select m.name, m.package, m.lic_license_text as license_text '
                               'from package_license pl join modules m on pl.license = m.name '
                               'where pl.package = ?',
                               ('//' + package,))
    rows = cursor.fetchall()
    licenses = {}
    for r in rows:
      licenses[r['name']] = r['license_text']
    return licenses

  def get_module_licenses(self, module_name, package):
    licenses = {}
    # If property "licenses" is defined on module
    cursor = self.conn.execute('select m.name, m.package, m.lic_license_text as license_text '
                               'from module_license ml join modules m on ml.license = m.name '
                               'where ml.module = ? and ml.package = ?',
                               (module_name, package))
    rows = cursor.fetchall()
    for r in rows:
      licenses[r['name']] = r['license_text']
    if len(licenses) > 0:
      return licenses

    # Use default package license
    cursor = self.conn.execute('select m.name, m.package, m.lic_license_text as license_text '
                               'from package_license pl join modules m on pl.license = m.name '
                               'where pl.package = ?',
                               ('//' + package,))
    rows = cursor.fetchall()
    for r in rows:
      licenses[r['name']] = r['license_text']
    return licenses

  def get_soong_module_of_installed_file(self, installed_file):
    cursor = self.conn.execute('select name, m.package, m.package as module_path, module_type as soong_module_type, built_files, installed_files, static_dep_files, whole_static_dep_files '
                               'from modules m join module_installed_file mif on m.id = mif.module_id '
                               'where mif.installed_file = ?',
                               (installed_file,))
    rows = cursor.fetchall()
    cursor.close()
    if rows:
      soong_module = dict(zip(rows[0].keys(), rows[0]))
      return soong_module

    return None

  def get_soong_module_of_built_file(self, built_file):
    cursor = self.conn.execute('select name, m.package, m.package as module_path, module_type as soong_module_type, built_files, installed_files, static_dep_files, whole_static_dep_files '
                               'from modules m join module_built_file mbf on m.id = mbf.module_id '
                               'where mbf.built_file = ?',
                               (built_file,))
    rows = cursor.fetchall()
    cursor.close()
    if rows:
      soong_module = dict(zip(rows[0].keys(), rows[0]))
      return soong_module

    return None