#
# Copyright (c) 2013-2017 SKYARCH NETWORKS INC.
#
# This software is released under the MIT License.
#
# http://opensource.org/licenses/mit-license.php
#

class ProjectCodeValidator < ActiveModel::Validator
  def validate(record)
    code = record.code
    if code == 'master'
      record.errors[:code] << "should not be 'master'"
      return
    end

    if code =~ /-read$/
      record.errors[:code] << "should not match /-read$/"
      return
    end

    if code =~ /-read-write$/
      record.errors[:code] << "should not match /-read-write$/"
      return
    end
  end
end
