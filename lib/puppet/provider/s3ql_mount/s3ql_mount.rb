#   Copyright 2015 Brainsware
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

Puppet::Type.type(:s3ql_mount).provide(:s3ql_mount) do

  desc 'Manage s3ql_mounts'

  mk_resource_methods

  # This is mostly for documentation purposes, since we have to execute most
  # commands as a specific user, we cannot use the #commands wrapper
  commands  :unused_mount_s3ql   => 'mount.s3ql'
  commands  :unused_umount_s3ql  => 'umount.s3ql'
  commands  :mount  => 'mount'

  def get_home(uid)
    require 'etc'
    if uid.is_a? Integer
      Etc.getpwuid(uid)[:dir]
    elsif uid.is_a? String
      Etc.getpwnam(uid)[:dir]
    end
    # nil is fine too..
  end

  def commands_wrapper(command, *arguments)
    env = { 'HOME' => get_home(@resource[:owner]) }
    Puppet::Util::Execution.execute([command, arguments], {
      :failonfail => true,
      :combine => true,
      :uid => @resource[:owner],
      :gid => @resource[:group],
      :custom_environment => env,
    })
  end

  def mount_s3ql(*arguments)
    commands_wrapper('mount.s3ql', arguments)
  end
  def umount_s3ql(*arguments)
    commands_wrapper('umount.s3ql', arguments)
  end

  def create
    mount_s3ql(@resource[:storage_url], @resource[:mountpoint])
    @property_hash = @resource
  end

  def destroy
    umount_s3ql(@resource[:mountpoint])
    @property_hash.clear
  end

  # get all fuse.s3ql mounted filesystems at the beginning
  def self.instances
    mounts = mount.split("\n").select { |line| line.include? "fuse.s3ql" }
    mounts.collect do |mnt|
      storage_url, _, mountpoint, _, _, options = mnt.split
      # and initialize @property_hash
      new( :name        => mountpoint,
           :mountpoint  => mountpoint,
           :ensure      => :present,
           :storage_url => storage_url,
           :owner       => options.sub(/.*user_id=(\d+).*/, '\1'),
           :group       => options.sub(/.*group_id=(\d+).*/, '\1'),
           :backend     => storage_url.split(':')[0]
         )
    end
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

end
