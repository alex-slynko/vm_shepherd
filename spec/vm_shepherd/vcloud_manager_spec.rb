require 'vm_shepherd/data_object'
require 'vm_shepherd/vcloud_manager'
require 'vm_shepherd/vcloud/deployer'
require 'vm_shepherd/vcloud/destroyer'
require 'vm_shepherd/vcloud/vapp_config'

module VmShepherd
  RSpec.describe VcloudManager do
    let(:login_info) do
      {
        url:          'FAKE_URL',
        organization: 'FAKE_ORGANIZATION',
        user:         'FAKE_USER',
        password:     'FAKE_PASSWORD',
      }
    end
    let(:vdc_name) { 'FAKE_VDC_NAME' }

    let(:logger) { instance_double(Logger).as_null_object }

    let(:vcloud_manager) { VcloudManager.new(login_info, vdc_name, logger) }

    describe '#deploy' do
      let(:vapp_config) do
        Vcloud::VappConfig.new(
          ip:      'FAKE_IP',
          name:    'FAKE_NAME',
          gateway: 'FAKE_GATEWAY',
          dns:     'FAKE_DNS',
          ntp:     'FAKE_NTP',
          netmask: 'FAKE_NETMASK',
          catalog: 'FAKE_VAPP_CATALOG',
          network: 'FAKE_NETWORK',
        )
      end

      let(:vapp_template_path) { 'FAKE_VAPP_TEMPLATE_PATH' }
      let(:tmpdir) { 'FAKE_TMP_DIR' }

      before { allow(Dir).to receive(:mktmpdir).and_return(tmpdir) }

      context 'when NO host exists at the specified IP' do
        let(:expanded_vapp_template_path) { 'FAKE_EXPANDED_VAPP_TEMPLATE_PATH' }

        before do
          allow(vcloud_manager).to receive(:system).with("ping -c 5 #{vapp_config.ip}").and_return(false)

          allow(File).to receive(:expand_path).with(vapp_template_path).and_return(expanded_vapp_template_path)

          allow(FileUtils).to receive(:remove_entry_secure)
        end

        it 'expands the vapp_template into a TMP dir' do
          command = "cd #{tmpdir} && tar xfv '#{expanded_vapp_template_path}'"
          expect(vcloud_manager).to receive(:system).with(command)

          expect { vcloud_manager.deploy(vapp_template_path, vapp_config) }.to raise_error(RuntimeError, /#{command}/)
        end

        context 'when the template can be expanded' do
          let(:client) { instance_double(VCloudSdk::Client) }
          let(:catalog) { instance_double(VCloudSdk::Catalog) }
          let(:network_config) { instance_double(VCloudSdk::NetworkConfig) }
          let(:vapp) { instance_double(VCloudSdk::VApp) }
          let(:vm) { instance_double(VCloudSdk::VM) }

          before do
            allow(vcloud_manager).to receive(:system).with("cd #{tmpdir} && tar xfv '#{expanded_vapp_template_path}'").
                and_return(true)
          end

          context 'when the vApp can be deployed' do
            let(:expected_properties) do
              [
                {
                  'type'             => 'string',
                  'key'              => 'gateway',
                  'value'            => vapp_config.gateway,
                  'password'         => 'false',
                  'userConfigurable' => 'true',
                  'Label'            => 'Default Gateway',
                  'Description'      => 'The default gateway address for the VM network. Leave blank if DHCP is desired.'
                },
                {
                  'type'             => 'string',
                  'key'              => 'DNS',
                  'value'            => vapp_config.dns,
                  'password'         => 'false',
                  'userConfigurable' => 'true',
                  'Label'            => 'DNS',
                  'Description'      => 'The domain name servers for the VM (comma separated). Leave blank if DHCP is desired.',
                },
                {
                  'type'             => 'string',
                  'key'              => 'ntp_servers',
                  'value'            => vapp_config.ntp,
                  'password'         => 'false',
                  'userConfigurable' => 'true',
                  'Label'            => 'NTP Servers',
                  'Description'      => 'Comma-delimited list of NTP servers'
                },
                {
                  'type'             => 'string',
                  'key'              => 'admin_password',
                  'value'            => 'tempest',
                  'password'         => 'true',
                  'userConfigurable' => 'true',
                  'Label'            => 'Admin Password',
                  'Description'      => 'This password is used to SSH into the VM. The username is "tempest".',
                },
                {
                  'type'             => 'string',
                  'key'              => 'ip0',
                  'value'            => vapp_config.ip,
                  'password'         => 'false',
                  'userConfigurable' => 'true',
                  'Label'            => 'IP Address',
                  'Description'      => 'The IP address for the VM. Leave blank if DHCP is desired.',
                },
                {
                  'type'             => 'string',
                  'key'              => 'netmask0',
                  'value'            => vapp_config.netmask,
                  'password'         => 'false',
                  'userConfigurable' => 'true',
                  'Label'            => 'Netmask',
                  'Description'      => 'The netmask for the VM network. Leave blank if DHCP is desired.'
                }
              ]
            end

            before do
              allow(VCloudSdk::Client).to receive(:new).and_return(client)
              allow(client).to receive(:catalog_exists?)
              allow(client).to receive(:delete_catalog_by_name)

              allow(client).to receive(:create_catalog).and_return(catalog)
              allow(catalog).to receive(:upload_vapp_template)
              allow(catalog).to receive(:instantiate_vapp_template).and_return(vapp)

              allow(VCloudSdk::NetworkConfig).to receive(:new).and_return(network_config)

              allow(vapp).to receive_message_chain(:vms, :first).and_return(vm)
              allow(vm).to receive(:product_section_properties=)
              allow(vapp).to receive(:power_on)
            end

            it 'uses VCloudSdk::Client' do
              expect(VCloudSdk::Client).to receive(:new).with(
                  login_info.fetch(:url),
                  [login_info.fetch(:user), login_info.fetch(:organization)].join('@'),
                  login_info.fetch(:password),
                  {},
                  logger,
                ).and_return(client)

              vcloud_manager.deploy(vapp_template_path, vapp_config)
            end

            it 'creates the catalog' do
              expect(client).to receive(:create_catalog).with(vapp_config.catalog).and_return(catalog)

              vcloud_manager.deploy(vapp_template_path, vapp_config)
            end

            it 'uploads the vApp template' do
              expect(catalog).to receive(:upload_vapp_template).with(
                  vdc_name,
                  vapp_config.name,
                  tmpdir,
                ).and_return(catalog)

              vcloud_manager.deploy(vapp_template_path, vapp_config)
            end

            it 'creates a VCloudSdk::NetworkConfig' do
              expect(VCloudSdk::NetworkConfig).to receive(:new).with(
                  vapp_config.network,
                  'Network 1',
                ).and_return(network_config)

              vcloud_manager.deploy(vapp_template_path, vapp_config)
            end

            it 'instantiates the vApp template' do
              expect(catalog).to receive(:instantiate_vapp_template).with(
                  vapp_config.name,
                  vdc_name,
                  vapp_config.name,
                  nil,
                  nil,
                  network_config
                ).and_return(vapp)

              vcloud_manager.deploy(vapp_template_path, vapp_config)
            end

            it 'sets the product section properties' do
              expect(vm).to receive(:product_section_properties=).with(expected_properties)

              vcloud_manager.deploy(vapp_template_path, vapp_config)
            end

            it 'powers on the vApp' do
              expect(vapp).to receive(:power_on)

              vcloud_manager.deploy(vapp_template_path, vapp_config)
            end

            it 'removes the expanded vApp template' do
              expect(FileUtils).to receive(:remove_entry_secure).with(tmpdir, force: true)

              vcloud_manager.deploy(vapp_template_path, vapp_config)
            end
          end

          context 'when the vApp can NOT be deployed' do
            let(:fake_deploy_error) { 'FAKE-VAPP-DEPLOY-ERROR' }

            before { allow(VCloudSdk::Client).to receive(:new).and_raise('FAKE-VAPP-DEPLOY-ERROR') }

            it 'removes the expanded vApp template' do
              expect(FileUtils).to receive(:remove_entry_secure).with(tmpdir, force: true)

              expect { vcloud_manager.deploy(vapp_template_path, vapp_config) }.to raise_error(/#{fake_deploy_error}/)
            end
          end
        end

        context 'when the template can NOT be expanded' do
          let(:tar_expand_cmd) { "cd #{tmpdir} && tar xfv '#{expanded_vapp_template_path}'" }
          before do
            allow(vcloud_manager).to receive(:system).with(tar_expand_cmd).and_return(false)
          end

          it 'raises an error' do
            expect { vcloud_manager.deploy(vapp_template_path, vapp_config) }.to raise_error("Error executing: #{tar_expand_cmd}")
          end

          it 'removes the expanded vApp template' do
            expect(FileUtils).to receive(:remove_entry_secure).with(tmpdir, force: true)

            expect { vcloud_manager.deploy(vapp_template_path, vapp_config) }.to raise_error(RuntimeError, /#{tar_expand_cmd}/)
          end
        end
      end

      context 'when a host exists at the specified IP' do
        before do
          allow(vcloud_manager).to receive(:system).with("ping -c 5 #{vapp_config.ip}").and_return(true)
        end

        it 'raises an error' do
          expect { vcloud_manager.deploy(vapp_template_path, vapp_config) }.to raise_error("VM exists at #{vapp_config.ip}")
        end

        it 'removes the expanded vApp template' do
          expect(FileUtils).to receive(:remove_entry_secure).with(tmpdir, force: true)

          expect { vcloud_manager.deploy(vapp_template_path, vapp_config) }.to raise_error(RuntimeError, /VM exists at FAKE_IP/)
        end
      end
    end

    describe '#destroy' do
      let(:client) { instance_double(VCloudSdk::Client) }
      let(:vapp_name) { 'FAKE_VAPP_NAME' }
      let(:vapp_catalog) { 'FAKE_VAPP_CATALOG' }

      before do
        allow(VCloudSdk::Client).to receive(:new).and_return(client)
      end

      it 'destroys everything including vapps' do
        destroyer = instance_double(VmShepherd::Vcloud::Destroyer)
        expect(VmShepherd::Vcloud::Destroyer).to receive(:new).with(client: client, vdc_name: vdc_name).and_return(destroyer)
        expect(destroyer).to receive(:clean_catalog_and_vapps).with(catalog: vapp_catalog, vapp_names: [vapp_name], logger: logger)

        vcloud_manager.destroy([vapp_name], vapp_catalog)
      end
    end

    describe '#clean_environment' do
      let(:client) { instance_double(VCloudSdk::Client) }
      let(:vapp_name) { ['VAPP_ONE', 'VAPP_TWO'] }
      let(:vapp_catalog) { 'VAPP_CATALOG' }

      before do
        allow(VCloudSdk::Client).to receive(:new).and_return(client)
      end

      it 'destroys the environment expect for vapps' do
        destroyer = instance_double(VmShepherd::Vcloud::Destroyer)
        expect(VmShepherd::Vcloud::Destroyer).to receive(:new).with(client: client, vdc_name: vdc_name).and_return(destroyer)
        expect(destroyer).to receive(:clean_catalog_and_vapps).with(catalog: vapp_catalog, vapp_names: [vapp_name], logger: logger)

        vcloud_manager.clean_environment([vapp_name], vapp_catalog)
      end
    end
  end
end
