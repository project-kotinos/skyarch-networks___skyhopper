#
# Copyright (c) 2013-2017 SKYARCH NETWORKS INC.
#
# This software is released under the MIT License.
#
# http://opensource.org/licenses/mit-license.php
#

module Concerns::Cryptize

  # @param [Symbol] name is an attributes name.
  def cryptize(name)
    c = crypter
    define_method(:"#{name}=") do |v|
      val = v.nil? ? v : c.encrypt_and_sign(v)
      self[name] = val
    end

    define_method(name) do
      v = self[name]
      v.nil? ? v : c.decrypt_and_verify(v)
    end
  end

  private
  def crypter
    secret = SkyHopper::Application.secrets[:db_crypt_key]
    ::ActiveSupport::MessageEncryptor.new(secret)
  end
end
