require 'vm_shepherd/backport_refinements'
using VmShepherd::BackportRefinements

require 'vm_shepherd/shepherd'

module VmShepherd
  RSpec.describe Shepherd do
    subject(:manager) { Shepherd.new(settings: settings) }
    let(:first_config) { settings.dig('vm_shepherd', 'vm_configs').first }
    let(:last_config) { settings.dig('vm_shepherd', 'vm_configs').last }
    let(:settings) { YAML.load_file(File.join(SPEC_ROOT, 'fixtures', 'shepherd', settings_fixture_name)) }
    let(:aws_env_config) do
      {
        'stack_name'     => 'aws-stack-name',
        'aws_access_key' => 'aws-access-key',
        'aws_secret_key' => 'aws-secret-key',
        'region'         => 'aws-region',
        'json_file'      => 'cloudformation.json',
        'parameters'     => {
          'key_pair_name' => 'key_pair_name'
        },
        'outputs'        => {
          'security_group'    => 'security-group-id',
          'public_subnet_id'  => 'public-subnet-id',
          'subnets'           => ['private-subnet-id', 'public-subnet-id'],
          's3_bucket_name'    => 'bucket-name',
        },
      }.merge(aws_elb_config)
    end
    let(:aws_elb_config) do
      {
        'elbs' =>  [
                {
                  'name'              => 'elb-1-name',
                  'port_mappings'     => [[1111, 11]],
                  'stack_output_keys' => {
                    'vpc_id'    => 'CloudFormationVpcIdOutputKey',
                    'subnet_id' => 'CloudFormationSubnetIdOutputKey',
                  },
                },
                {
                  'name'              => 'elb-2-name',
                  'port_mappings'     => [[2222, 22]],
                  'stack_output_keys' => {
                    'vpc_id'    => 'CloudFormationVpcIdOutputKey',
                    'subnet_id' => 'CloudFormationSubnetIdOutputKey',
                  },
                }
              ],
      }
    end

    describe '#deploy' do
      context 'with vcloud settings' do
        let(:settings_fixture_name) { 'vcloud.yml' }
        let(:first_vcloud_manager) { instance_double(VcloudManager) }
        let(:last_vcloud_manager) { instance_double(VcloudManager) }

        it 'uses VcloudManager to launch a vm' do
          expect(VcloudManager).to receive(:new).
            with(
              {
                url:          first_config.dig('creds', 'url'),
                organization: first_config.dig('creds', 'organization'),
                user:         first_config.dig('creds', 'user'),
                password:     first_config.dig('creds', 'password'),
              },
              first_config.dig('vdc', 'name'),
              instance_of(Logger)
            ).and_return(first_vcloud_manager)

          expect(VcloudManager).to receive(:new).
            with(
              {
                url:          last_config.dig('creds', 'url'),
                organization: last_config.dig('creds', 'organization'),
                user:         last_config.dig('creds', 'user'),
                password:     last_config.dig('creds', 'password'),
              },
              last_config.dig('vdc', 'name'),
              instance_of(Logger)
            ).and_return(last_vcloud_manager)

          expect(first_vcloud_manager).to receive(:deploy).with(
            'FIRST_FAKE_PATH',
            Vcloud::VappConfig.new(
              name:    first_config.dig('vapp', 'ops_manager_name'),
              ip:      first_config.dig('vapp', 'ip'),
              gateway: first_config.dig('vapp', 'gateway'),
              netmask: first_config.dig('vapp', 'netmask'),
              dns:     first_config.dig('vapp', 'dns'),
              ntp:     first_config.dig('vapp', 'ntp'),
              catalog: first_config.dig('vdc', 'catalog'),
              network: first_config.dig('vdc', 'network'),
            )
          )

          expect(last_vcloud_manager).to receive(:deploy).with(
            'LAST_FAKE_PATH',
            Vcloud::VappConfig.new(
              name:    last_config.dig('vapp', 'ops_manager_name'),
              ip:      last_config.dig('vapp', 'ip'),
              gateway: last_config.dig('vapp', 'gateway'),
              netmask: last_config.dig('vapp', 'netmask'),
              dns:     last_config.dig('vapp', 'dns'),
              ntp:     last_config.dig('vapp', 'ntp'),
              catalog: last_config.dig('vdc', 'catalog'),
              network: last_config.dig('vdc', 'network'),
            )
          )

          manager.deploy(paths: ['FIRST_FAKE_PATH', 'LAST_FAKE_PATH'])
        end

        it 'fails if improper paths are given' do
          expect { manager.deploy(paths: ['FIRST_FAKE_PATH']) }.to raise_error(ArgumentError)
        end
      end

      context 'with vsphere settings' do
        let(:settings_fixture_name) { 'vsphere.yml' }
        let(:first_ova_manager) { instance_double(VsphereManager) }
        let(:last_ova_manager) { instance_double(VsphereManager) }

        it 'uses VsphereManager to launch a vm' do
          expect(VsphereManager).to receive(:new).with(
            first_config.dig('vcenter_creds', 'ip'),
            first_config.dig('vcenter_creds', 'username'),
            first_config.dig('vcenter_creds', 'password'),
            first_config.dig('vsphere', 'datacenter'),
            instance_of(Logger),
          ).and_return(first_ova_manager)

          expect(VsphereManager).to receive(:new).with(
            last_config.dig('vcenter_creds', 'ip'),
            last_config.dig('vcenter_creds', 'username'),
            last_config.dig('vcenter_creds', 'password'),
            last_config.dig('vsphere', 'datacenter'),
            instance_of(Logger),
          ).and_return(last_ova_manager)

          expect(first_ova_manager).to receive(:deploy).with(
            'FIRST_FAKE_PATH',
            {
              ip:          first_config.dig('vm', 'ip'),
              gateway:     first_config.dig('vm', 'gateway'),
              netmask:     first_config.dig('vm', 'netmask'),
              dns:         first_config.dig('vm', 'dns'),
              ntp_servers: first_config.dig('vm', 'ntp_servers'),
              cpus:        first_config.dig('vm', 'cpus'),
              ram_mb:      first_config.dig('vm', 'ram_mb'),
            },
            {
              cluster:       first_config.dig('vsphere', 'cluster'),
              resource_pool: first_config.dig('vsphere', 'resource_pool'),
              datastore:     first_config.dig('vsphere', 'datastore'),
              network:       first_config.dig('vsphere', 'network'),
              folder:        first_config.dig('vsphere', 'folder'),
            },
          )

          expect(last_ova_manager).to receive(:deploy).with(
            'LAST_FAKE_PATH',
            {
              ip:          last_config.dig('vm', 'ip'),
              gateway:     last_config.dig('vm', 'gateway'),
              netmask:     last_config.dig('vm', 'netmask'),
              dns:         last_config.dig('vm', 'dns'),
              ntp_servers: last_config.dig('vm', 'ntp_servers'),
              cpus:        last_config.dig('vm', 'cpus'),
              ram_mb:      last_config.dig('vm', 'ram_mb'),
            },
            {
              cluster:       last_config.dig('vsphere', 'cluster'),
              resource_pool: last_config.dig('vsphere', 'resource_pool'),
              datastore:     last_config.dig('vsphere', 'datastore'),
              network:       last_config.dig('vsphere', 'network'),
              folder:        last_config.dig('vsphere', 'folder'),
            },
          )

          manager.deploy(paths: ['FIRST_FAKE_PATH', 'LAST_FAKE_PATH'])
        end

        it 'fails if improper paths are given' do
          expect { manager.deploy(paths: ['FIRST_FAKE_PATH']) }.to raise_error(ArgumentError)
        end
      end

      context 'with AWS settings' do
        let(:settings_fixture_name) { 'aws.yml' }
        let(:aws_manager) { instance_double(AwsManager) }
        let(:first_ami_file_path) { 'PATH_TO_AMI_FILE' }
        let(:last_ami_file_path) { 'PATH_TO_AMI_FILE-2' }
        let(:first_aws_options) { {'vm_name' => 'vm-name', 'key_name' => 'ssh-key-name'} }
        let(:last_aws_options) { {'vm_name' => 'vm-name-2', 'key_name' => 'ssh-key-name-2'} }

        it 'uses AwsManager to launch a VM' do
          expect(AwsManager).to receive(:new).with(env_config: aws_env_config, logger: instance_of(Logger)).and_return(aws_manager)
          expect(aws_manager).to receive(:deploy).with(ami_file_path: first_ami_file_path, vm_config: first_aws_options)
          expect(aws_manager).to receive(:deploy).with(ami_file_path: last_ami_file_path, vm_config: last_aws_options)

          manager.deploy(paths: [first_ami_file_path, last_ami_file_path])
        end

        it 'fails if improper paths are given' do
          expect { manager.deploy(paths: ['FIRST_FAKE_PATH']) }.to raise_error(ArgumentError)
        end

        context 'when there is no ELB configuration' do
          let(:settings_fixture_name) { 'aws-no-elb.yml' }
          let(:aws_elb_config) { {} }

          it 'uses AwsManager to launch a VM' do
            expect(AwsManager).to receive(:new).with(env_config: aws_env_config, logger: instance_of(Logger)).and_return(aws_manager)
            expect(aws_manager).to receive(:deploy).with(ami_file_path: first_ami_file_path, vm_config: first_aws_options)
            expect(aws_manager).to receive(:deploy).with(ami_file_path: last_ami_file_path, vm_config: last_aws_options)

            manager.deploy(paths: [first_ami_file_path, last_ami_file_path])
          end
        end
      end

      context 'with OpenStack settings' do
        let(:settings_fixture_name) { 'openstack.yml' }
        let(:first_qcow2_file_path) { 'PATH_TO_QCOW2_FILE' }
        let(:last_qcow2_file_path) { 'PATH_TO_QCOW2_FILE-2' }
        let(:first_qcow2_manager) { instance_double(OpenstackManager) }
        let(:last_qcow2_manager) { instance_double(OpenstackManager) }
        let(:first_openstack_options) do
          {
            auth_url: 'http://example.com/version/tokens',
            username: 'username',
            api_key:  'api-key',
            tenant:   'tenant',
          }
        end
        let(:last_openstack_options) do
          {
            auth_url: 'http://example.com/version/tokens-2',
            username: 'username-2',
            api_key:  'api-key-2',
            tenant:   'tenant-2',
          }
        end
        let(:first_openstack_vm_options) do
          {
            name:                 'some-vm-name',
            flavor_name:          'some-flavor',
            network_name:         'some-network',
            key_name:             'some-key',
            security_group_names: [
                                    'security-group-A',
                                    'security-group-B',
                                    'security-group-C',
                                  ],
            public_ip:            '198.11.195.5',
            private_ip:           '192.168.100.100',
          }
        end
        let(:last_openstack_vm_options) do
          {
            name:                 'some-vm-name-2',
            flavor_name:          'some-flavor-2',
            network_name:         'some-network-2',
            key_name:             'some-key-2',
            security_group_names: [
                                    'security-group-A-2',
                                    'security-group-B-2',
                                    'security-group-C-2',
                                  ],
            public_ip:            '198.11.195.5-2',
            private_ip:           '192.168.100.100-2',
          }
        end

        it 'uses OpenstackManager to launch a VM' do
          expect(OpenstackManager).to receive(:new).with(first_openstack_options).and_return(first_qcow2_manager)
          expect(first_qcow2_manager).to receive(:deploy).with(first_qcow2_file_path, first_openstack_vm_options)

          expect(OpenstackManager).to receive(:new).with(last_openstack_options).and_return(last_qcow2_manager)
          expect(last_qcow2_manager).to receive(:deploy).with(last_qcow2_file_path, last_openstack_vm_options)

          manager.deploy(paths: [first_qcow2_file_path, last_qcow2_file_path])
        end

        it 'fails if improper paths are given' do
          expect { manager.deploy(paths: ['FIRST_FAKE_PATH']) }.to raise_error(ArgumentError)
        end
      end

      context 'when IAAS is unknown' do
        let(:settings_fixture_name) { 'unknown.yml' }

        it 'raises an exception' do
          expect { manager.deploy(paths: ['FAKE_PATH']) }.to raise_error(Shepherd::InvalidIaas)
        end
      end
    end

    describe '#destroy' do
      context 'when IAAS is vcloud' do
        let(:settings_fixture_name) { 'vcloud.yml' }
        let(:first_vcloud_manager) { instance_double(VcloudManager) }
        let(:last_vcloud_manager) { instance_double(VcloudManager) }

        it 'uses VcloudManager to destroy a vm' do
          expect(VcloudManager).to receive(:new).with(
            {
              url:          first_config.dig('creds', 'url'),
              organization: first_config.dig('creds', 'organization'),
              user:         first_config.dig('creds', 'user'),
              password:     first_config.dig('creds', 'password'),
            },
            first_config.dig('vdc', 'name'),
            instance_of(Logger)
          ).and_return(first_vcloud_manager)

          expect(first_vcloud_manager).to receive(:destroy).with(
            [first_config.dig('vapp', 'ops_manager_name')],
            first_config.dig('vdc', 'catalog'),
          )

          expect(VcloudManager).to receive(:new).with(
            {
              url:          last_config.dig('creds', 'url'),
              organization: last_config.dig('creds', 'organization'),
              user:         last_config.dig('creds', 'user'),
              password:     last_config.dig('creds', 'password'),
            },
            last_config.dig('vdc', 'name'),
            instance_of(Logger)
          ).and_return(last_vcloud_manager)

          expect(last_vcloud_manager).to receive(:destroy).with(
            [last_config.dig('vapp', 'ops_manager_name')],
            last_config.dig('vdc', 'catalog'),
          )

          manager.destroy
        end
      end

      context 'when IAAS is vsphere' do
        let(:settings_fixture_name) { 'vsphere.yml' }
        let(:first_ova_manager) { instance_double(VsphereManager) }
        let(:last_ova_manager) { instance_double(VsphereManager) }

        it 'uses VsphereManager to destroy a vm' do
          expect(VsphereManager).to receive(:new).with(
            first_config.dig('vcenter_creds', 'ip'),
            first_config.dig('vcenter_creds', 'username'),
            first_config.dig('vcenter_creds', 'password'),
            first_config.dig('vsphere', 'datacenter'),
            instance_of(Logger),
          ).and_return(first_ova_manager)
          expect(first_ova_manager).to receive(:destroy).with(first_config.dig('vm', 'ip'), first_config.dig('vsphere', 'resource_pool'))

          expect(VsphereManager).to receive(:new).with(
            last_config.dig('vcenter_creds', 'ip'),
            last_config.dig('vcenter_creds', 'username'),
            last_config.dig('vcenter_creds', 'password'),
            last_config.dig('vsphere', 'datacenter'),
            instance_of(Logger),
          ).and_return(last_ova_manager)
          expect(last_ova_manager).to receive(:destroy).with(last_config.dig('vm', 'ip'), last_config.dig('vsphere', 'resource_pool'))

          manager.destroy
        end
      end

      context 'when IAAS is AWS' do
        let(:settings_fixture_name) { 'aws.yml' }
        let(:aws_manager) { instance_double(AwsManager) }
        let(:first_ami_options) { {'vm_name' => 'vm-name', 'key_name' => 'ssh-key-name'} }
        let(:last_ami_options) { {'vm_name' => 'vm-name-2', 'key_name' => 'ssh-key-name-2'} }

        it 'uses AwsManager to destroy a VM' do
          expect(AwsManager).to receive(:new).with(env_config: aws_env_config, logger: instance_of(Logger)).and_return(aws_manager)
          expect(aws_manager).to receive(:destroy).with(first_ami_options)
          expect(aws_manager).to receive(:destroy).with(last_ami_options)

          manager.destroy
        end

        context 'when there is no ELB configuration' do
          let(:settings_fixture_name) { 'aws-no-elb.yml' }
          let(:aws_elb_config) { {} }

          it 'uses AwsManager to destroy a VM' do
            expect(AwsManager).to receive(:new).with(env_config: aws_env_config, logger: instance_of(Logger)).and_return(aws_manager)
            expect(aws_manager).to receive(:destroy).with(first_ami_options)
            expect(aws_manager).to receive(:destroy).with(last_ami_options)

            manager.destroy
          end
        end
      end

      context 'when IAAS is Openstack' do
        let(:settings_fixture_name) { 'openstack.yml' }
        let(:qcow2_file_path) { 'PATH_TO_QCOW2_FILE' }
        let(:first_qcow2_manager) { instance_double(OpenstackManager) }
        let(:last_qcow2_manager) { instance_double(OpenstackManager) }
        let(:first_openstack_options) do
          {
            auth_url: 'http://example.com/version/tokens',
            username: 'username',
            api_key:  'api-key',
            tenant:   'tenant',
          }
        end
        let(:first_openstack_vm_options) do
          {
            name:                 'some-vm-name',
            flavor_name:          'some-flavor',
            network_name:         'some-network',
            key_name:             'some-key',
            security_group_names: [
                                    'security-group-A',
                                    'security-group-B',
                                    'security-group-C',
                                  ],
            public_ip:            '198.11.195.5',
            private_ip:           '192.168.100.100',
          }
        end
        let(:last_openstack_options) do
          {
            auth_url: 'http://example.com/version/tokens-2',
            username: 'username-2',
            api_key:  'api-key-2',
            tenant:   'tenant-2',
          }
        end
        let(:last_openstack_vm_options) do
          {
            name:                 'some-vm-name-2',
            flavor_name:          'some-flavor-2',
            network_name:         'some-network-2',
            key_name:             'some-key-2',
            security_group_names: [
                                    'security-group-A-2',
                                    'security-group-B-2',
                                    'security-group-C-2',
                                  ],
            public_ip:            '198.11.195.5-2',
            private_ip:           '192.168.100.100-2',
          }
        end

        it 'uses OpenstackManager to destroy a VM' do
          expect(OpenstackManager).to receive(:new).with(first_openstack_options).and_return(first_qcow2_manager)
          expect(first_qcow2_manager).to receive(:destroy).with(first_openstack_vm_options)

          expect(OpenstackManager).to receive(:new).with(last_openstack_options).and_return(last_qcow2_manager)
          expect(last_qcow2_manager).to receive(:destroy).with(last_openstack_vm_options)

          manager.destroy
        end
      end

      context 'when IAAS is unknown' do
        let(:settings_fixture_name) { 'unknown.yml' }

        it 'raises an exception' do
          expect { manager.destroy }.to raise_error(Shepherd::InvalidIaas)
        end
      end
    end

    describe '#clean_environment' do
      context 'when IAAS is vcloud' do
        let(:settings_fixture_name) { 'vcloud.yml' }
        let(:first_vcloud_manager) { instance_double(VcloudManager) }
        let(:last_vcloud_manager) { instance_double(VcloudManager) }

        it 'uses VcloudManager to destroy a vm' do
          expect(VcloudManager).to receive(:new).with(
            {
              url:          first_config.dig('creds', 'url'),
              organization: first_config.dig('creds', 'organization'),
              user:         first_config.dig('creds', 'user'),
              password:     first_config.dig('creds', 'password'),
            },
            first_config.dig('vdc', 'name'),
            instance_of(Logger)
          ).and_return(first_vcloud_manager)

          expect(first_vcloud_manager).to receive(:clean_environment).with(
            first_config.dig('vapp', 'product_names'),
            first_config.dig('vapp', 'product_catalog'),
          )

          expect(VcloudManager).to receive(:new).with(
            {
              url:          last_config.dig('creds', 'url'),
              organization: last_config.dig('creds', 'organization'),
              user:         last_config.dig('creds', 'user'),
              password:     last_config.dig('creds', 'password'),
            },
            last_config.dig('vdc', 'name'),
            instance_of(Logger)
          ).and_return(last_vcloud_manager)

          expect(last_vcloud_manager).to receive(:clean_environment).with(
            [],
            last_config.dig('vapp', 'product_catalog'),
          )

          manager.clean_environment
        end
      end

      context 'when IAAS is vsphere' do
        let(:settings_fixture_name) { 'vsphere.yml' }
        let(:first_ova_manager) { instance_double(VsphereManager) }
        let(:first_clean_environment_options) do
          {
            datacenter_folders_to_clean: first_config.dig('cleanup', 'datacenter_folders_to_clean'),
            datastores:                  first_config.dig('cleanup', 'datastores'),
            datastore_folders_to_clean:  first_config.dig('cleanup', 'datastore_folders_to_clean'),
          }
        end
        let(:last_ova_manager) { instance_double(VsphereManager) }
        let(:last_clean_environment_options) do
          {
            datacenter_folders_to_clean: last_config.dig('cleanup', 'datacenter_folders_to_clean'),
            datastores:                  last_config.dig('cleanup', 'datastores'),
            datastore_folders_to_clean:  last_config.dig('cleanup', 'datastore_folders_to_clean'),
          }
        end

        it 'uses VsphereManager to destroy a vm' do
          expect(VsphereManager).to receive(:new).with(
            first_config.dig('vcenter_creds', 'ip'),
            first_config.dig('vcenter_creds', 'username'),
            first_config.dig('vcenter_creds', 'password'),
            first_config.dig('cleanup', 'datacenter'),
            instance_of(Logger),
          ).and_return(first_ova_manager)
          expect(first_ova_manager).to receive(:clean_environment).with(first_clean_environment_options)
          expect(VsphereManager).to receive(:new).with(
            last_config.dig('vcenter_creds', 'ip'),
            last_config.dig('vcenter_creds', 'username'),
            last_config.dig('vcenter_creds', 'password'),
            last_config.dig('cleanup', 'datacenter'),
            instance_of(Logger),
          ).and_return(last_ova_manager)
          expect(last_ova_manager).to receive(:clean_environment).with(last_clean_environment_options)

          manager.clean_environment
        end
      end

      context 'when IAAS is AWS' do
        let(:settings_fixture_name) { 'aws.yml' }
        let(:aws_manager) { instance_double(AwsManager) }

        it 'uses AwsManager to destroy a VM' do
          expect(AwsManager).to receive(:new).with(env_config: aws_env_config, logger: instance_of(Logger)).and_return(aws_manager)
          expect(aws_manager).to receive(:clean_environment)
          manager.clean_environment
        end

        context 'when there is no ELB configuration' do
          let(:settings_fixture_name) { 'aws-no-elb.yml' }
          let(:aws_elb_config) { {} }

          it 'uses AwsManager to destroy a VM' do
            expect(AwsManager).to receive(:new).with(env_config: aws_env_config, logger: instance_of(Logger)).and_return(aws_manager)
            expect(aws_manager).to receive(:clean_environment)
            manager.clean_environment
          end
        end
      end

      context 'when IAAS is Openstack' do
        let(:settings_fixture_name) { 'openstack.yml' }
        let(:qcow2_file_path) { 'PATH_TO_QCOW2_FILE' }
        let(:first_qcow2_manager) { instance_double(OpenstackManager) }
        let(:first_openstack_options) do
          {
            auth_url: 'http://example.com/version/tokens',
            username: 'username',
            api_key:  'api-key',
            tenant:   'tenant',
          }
        end
        let(:last_qcow2_manager) { instance_double(OpenstackManager) }
        let(:last_openstack_options) do
          {
            auth_url: 'http://example.com/version/tokens-2',
            username: 'username-2',
            api_key:  'api-key-2',
            tenant:   'tenant-2',
          }
        end

        it 'uses OpenstackManager to destroy a VM' do
          expect(OpenstackManager).to receive(:new).with(first_openstack_options).and_return(first_qcow2_manager)
          expect(first_qcow2_manager).to receive(:clean_environment)
          expect(OpenstackManager).to receive(:new).with(last_openstack_options).and_return(last_qcow2_manager)
          expect(last_qcow2_manager).to receive(:clean_environment)
          manager.clean_environment
        end
      end

      context 'when IAAS is unknown' do
        let(:settings_fixture_name) { 'unknown.yml' }

        it 'raises an exception' do
          expect { manager.clean_environment }.to raise_error(Shepherd::InvalidIaas)
        end
      end
    end

    describe '#prepare_environment' do
      context 'when IAAS is AWS' do
        let(:settings_fixture_name) { 'aws.yml' }
        let(:ams_manager) { instance_double(AwsManager) }

        it 'uses AwsManager to create an environment' do
          expect(AwsManager).to receive(:new).with(env_config: aws_env_config, logger: instance_of(Logger)).and_return(ams_manager)
          expect(ams_manager).to receive(:prepare_environment).with('cloudformation.json')
          manager.prepare_environment
        end

        context 'when there is no ELB configuration' do
          let(:settings_fixture_name) { 'aws-no-elb.yml' }
          let(:aws_elb_config) { {} }

          it 'uses AwsManager to create an environment' do
            expect(AwsManager).to receive(:new).with(env_config: aws_env_config, logger: instance_of(Logger)).and_return(ams_manager)
            expect(ams_manager).to receive(:prepare_environment).with('cloudformation.json')
            manager.prepare_environment
          end
        end
      end

      context 'when IAAS is vcloud' do
        let(:settings_fixture_name) { 'vcloud.yml' }
        let(:first_vcloud_manager) { instance_double(VcloudManager) }
        let(:last_vcloud_manager) { instance_double(VcloudManager) }

        it 'uses VcloudManager to destroy a vm' do
          expect(VcloudManager).to receive(:new).with(
            {
              url:          first_config.dig('creds', 'url'),
              organization: first_config.dig('creds', 'organization'),
              user:         first_config.dig('creds', 'user'),
              password:     first_config.dig('creds', 'password'),
            },
            first_config.dig('vdc', 'name'),
            instance_of(Logger)
          ).and_return(first_vcloud_manager)

          expect(first_vcloud_manager).to receive(:prepare_environment)

          expect(VcloudManager).to receive(:new).with(
            {
              url:          last_config.dig('creds', 'url'),
              organization: last_config.dig('creds', 'organization'),
              user:         last_config.dig('creds', 'user'),
              password:     last_config.dig('creds', 'password'),
            },
            last_config.dig('vdc', 'name'),
            instance_of(Logger)
          ).and_return(last_vcloud_manager)

          expect(last_vcloud_manager).to receive(:prepare_environment)
          manager.prepare_environment
        end
      end

      context 'when IAAS is vsphere' do
        let(:settings_fixture_name) { 'vsphere.yml' }
        let(:first_ova_manager) { instance_double(VsphereManager) }
        let(:last_ova_manager) { instance_double(VsphereManager) }

        it 'uses VsphereManager to destroy a vm' do
          expect(VsphereManager).to receive(:new).with(
            first_config.dig('vcenter_creds', 'ip'),
            first_config.dig('vcenter_creds', 'username'),
            first_config.dig('vcenter_creds', 'password'),
            first_config.dig('vsphere', 'datacenter'),
            instance_of(Logger),
          ).and_return(first_ova_manager)
          expect(first_ova_manager).to receive(:prepare_environment)
          expect(VsphereManager).to receive(:new).with(
            last_config.dig('vcenter_creds', 'ip'),
            last_config.dig('vcenter_creds', 'username'),
            last_config.dig('vcenter_creds', 'password'),
            last_config.dig('vsphere', 'datacenter'),
            instance_of(Logger),
          ).and_return(last_ova_manager)
          expect(last_ova_manager).to receive(:prepare_environment)

          manager.prepare_environment
        end
      end

      context 'when IAAS is Openstack' do
        let(:settings_fixture_name) { 'openstack.yml' }
        let(:first_openstack_manager) { instance_double(OpenstackManager) }
        let(:first_openstack_options) do
          {
            auth_url: 'http://example.com/version/tokens',
            username: 'username',
            api_key:  'api-key',
            tenant:   'tenant',
          }
        end
        let(:last_openstack_manager) { instance_double(OpenstackManager) }
        let(:last_openstack_options) do
          {
            auth_url: 'http://example.com/version/tokens-2',
            username: 'username-2',
            api_key:  'api-key-2',
            tenant:   'tenant-2',
          }
        end

        it 'uses OpenstackManager to destroy a VM' do
          expect(OpenstackManager).to receive(:new).with(first_openstack_options).and_return(first_openstack_manager)
          expect(first_openstack_manager).to receive(:prepare_environment)
          expect(OpenstackManager).to receive(:new).with(last_openstack_options).and_return(last_openstack_manager)
          expect(last_openstack_manager).to receive(:prepare_environment)
          manager.prepare_environment
        end
      end

      context 'when IAAS is unknown' do
        let(:settings_fixture_name) { 'unknown.yml' }

        it 'raises an exception' do
          expect { manager.prepare_environment }.to raise_error(Shepherd::InvalidIaas)
        end
      end
    end
  end
end
