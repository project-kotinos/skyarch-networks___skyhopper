#
# Copyright (c) 2013-2015 SKYARCH NETWORKS INC.
#
# This software is released under the MIT License.
#
# http://opensource.org/licenses/mit-license.php
#

require_relative '../spec_helper'

describe NodesController, :type => :controller do
  login_user
  let(:infra){create(:infrastructure)}
  let(:physical_id){'i-hogehoge'}

  # TODO: Threadつらい
  describe 'GET #run bootstrap' do
    before do
      allow(Thread).to receive(:new_with_db)
      get :run_bootstrap, id: physical_id, infra_id: infra.id
    end

    should_be_success
  end

  describe "#show" do

    let(:request){get :show, infra_id: infra.id, id: physical_id, format: 'json'}

    # mocks
    let(:instance){double('instance')}
    let(:instance_status){:running} # 各コンテキストで場合によって上書き
    let(:instance_summary){{status: instance_status}}
    let(:cook_status){'Success'}
    let(:serverspec_status){'UnExecuted'}
    let(:update_status){'Failed'}
    before do
      allow_any_instance_of(Infrastructure).to receive(:instance).and_return(instance)
      allow(instance).to receive(:summary).and_return(instance_summary)
      Rails.cache.write(CookStatus::TagName       + physical_id, cook_status)
      Rails.cache.write(ServerspecStatus::TagName + physical_id, serverspec_status)
      Rails.cache.write(UpdateStatus::TagName     + physical_id, update_status)
    end

    let(:chef_server){double('chef-server')}
    let(:chef_running){true}
    before do
      allow(ServerState).to receive(:new).and_return(chef_server)
      allow(chef_server).to receive(:is_running?).and_return(chef_running)
    end

    let(:dish){create(:dish)}
    let(:details){{
      "run_list" => ['a', 'b', 'f'],
      'normal' => {
        'dish_id' => dish.id
      }
    }}
    before do
      allow_any_instance_of(Node).to receive(:details).and_return(details)
    end


    [:terminated, :stopped].each do |state|
      context "when instance #{state}" do
        let(:instance_status){state}
        before{request}

        should_be_success
        it 'should assign @instance_summary' do
          expect(assigns[:instance_summary]).to eq instance_summary
        end
      end
    end

    context 'when chef server stopped' do
      let(:chef_running){false}
      before{request}

      it '@chef_error should be true' do
        expect(assigns[:chef_error]).to be true
      end

      it 'should assign @chef_msg' do
        expect(assigns[:chef_msg]).to be_a String
      end
    end

    context 'when before bootstrap' do
      before do
        allow_any_instance_of(Node).to receive(:details).and_raise(ChefAPI::Error::NotFound)
      end
      before{request}

      it '@before_bootstrap should be true' do
        expect(assigns[:before_bootstrap]).to be true
      end
    end

    context 'when chef api error' do
      let(:error_msg){'Internal server error'}
      before do
        allow_any_instance_of(Node).to receive(:details).and_raise(ChefAPI::Error, error_msg)
      end
      before{request}

      it '@chef_error should be true' do
        expect(assigns[:chef_error]).to eq true
      end

      it 'should assigns @chef_msg' do
        expect(assigns[:chef_msg]).to eq error_msg
      end
    end

    context 'when all success' do
      before{request}
      it 'should assigns @runlist' do
        expect(assigns[:runlist]).to eq details['run_list']
      end

      it 'should assigns @selected_dish' do
        expect(assigns[:selected_dish]).to eq details['normal']['dish_id']
      end

      it 'should assigns @info' do
        expect(assigns[:info]).to be_a Hash
        expect(assigns[:info][:cook_status]).to eq cook_status
        expect(assigns[:info][:serverspec_status]).to eq serverspec_status
        expect(assigns[:info][:update_status]).to eq update_status
      end

      it 'should assigns @dishes' do
        expect(assigns[:dishes]).to eq Dish.valid_dishes(infra.project_id)
      end
    end
  end

  describe "#POST cook" do
    let(:cook_request){post :cook, id: physical_id, infra_id: infra.id}

    before do
      expect_any_instance_of(NodesController).to receive(:cook_nodes).with(infra, physical_id)
      cook_request
    end

    it "should render" do
      expect(response.body).not_to be nil
    end

    it "should be success" do
      expect(response.status).to eq 202
    end
  end

  describe '#edit' do
    let(:req){get :edit, id: physical_id, infra_id: infra.id}
    let(:details){{"run_list" => ['foo', 'bar']}}
    let(:roles){[double('role1', name: 'ROLE1'), double('role2', name: 'ROLE2')]}
    let(:cookbooks){{hoge: 'Hoge Cookbook', fuga: 'Fuga Cookbook'}}

    before do
      allow_any_instance_of(Node).to receive(:details).and_return(details)
      allow(ChefAPI).to receive(:index).with(:role).and_return(roles)
      allow(ChefAPI).to receive(:index).with(:cookbook).and_return(cookbooks)
      req
    end

    should_be_success

    it 'should assign @runlist' do
      expect(assigns[:runlist]).to eq details['run_list']
    end

    it 'should assign @roles' do
      expect(assigns[:roles]).to eq roles.map(&:name).sort
    end

    it 'should assign @cookbooks' do
      expect(assigns[:cookbooks]).to eq cookbooks.keys.sort
    end
  end

  describe '#recipes' do
    let(:recipes){%w[default package source]}
    let(:cookbook){'apache'}
    before do
      allow(ChefAPI).to receive(:recipes).and_return(recipes)
    end

    before{get :recipes, cookbook: cookbook}

    should_be_success

    it 'should assign @recipes' do
      expect(assigns[:recipes]).to eq recipes.sort
    end
  end

  describe '#update' do
    let(:runlist){['a', 'b', 'c']}
    let(:req){put :update, id: physical_id, infra_id: infra.id, runlist: runlist}
    let(:status){true}
    let(:message){'hogefuga piyoyo'}

    before do
      allow_any_instance_of(NodesController).to receive(:update_runlist)
        .with(physical_id: physical_id, infrastructure: infra, runlist: runlist)
        .and_return({status: status, message: message})
      req
    end

    context 'when update success' do
      should_be_success

      it 'should render text' do
        expect(response.body).to eq I18n.t('nodes.msg.runlist_updated')
      end
    end

    context 'when update fail' do
      let(:status){false}
      should_be_failure

      it 'should render text' do
        expect(response.body).to eq message
      end
    end
  end

  describe '#apply dish' do
    let(:dish){create(:dish)}
    let(:node){double(:node)}
    let(:ret){{status: status, message: "message"}}

    let(:dish_apply_request){post :apply_dish, id: physical_id, infra_id: infra.id, dish_id: dish.id}

    before do
      allow(Dish).to receive(:find).with(dish.id.to_s).and_return(dish)
      allow(Node).to receive(:new).with(physical_id).and_return(node)
    end

    context "when runlist present?" do
      before do
        expect_any_instance_of(NodesController).to receive(:update_runlist)
          .with(physical_id: physical_id, infrastructure: infra, runlist: dish.runlist, dish_id: dish.id.to_s).and_return(ret)
      end

      context "unless ret[:status]" do
        let(:status){nil}

        before do
          dish_apply_request
        end

        it "should render text" do
          expect(response.body).not_to be nil
        end

        it "should return status code 500" do
          expect(response.status).to eq 500
        end
      end
    end
  end

  describe '#update_attributes' do
    let(:attributes){JSON.generate({'yum_releasever/releasever' => '2014.09', 'zabbix/agent/servers' => 'example.com'})}
    let(:req){put :update_attributes, id: physical_id, infra_id: infra.id, attributes: attributes}

    context 'update success' do
      before do
        allow_any_instance_of(Node).to receive(:update_attributes)
        req
      end
      should_be_success

      it 'should render text' do
        expect(response.body).to eq I18n.t('nodes.msg.attribute_updated')
      end
    end

    context 'update failures' do
      let(:msg){'!!!ERROR!!!'}
      before do
        allow_any_instance_of(Node).to receive(:update_attributes).and_raise(msg)
        req
      end
      should_be_failure

      it 'should render text' do
        expect(response.body).to eq msg
      end
    end
  end

  describe '#edit_attributes' do
    let(:req){get :edit_attributes, id: physical_id, infra_id: infra.id}
    let(:attrs){{foo: {bar: 'hoge'}}}
    let(:current_attr){{foo: 'piyopiyo'}}
    let(:node){double(:node, enabled_attributes: attrs, get_attributes: current_attr)}
    before do
      allow(Node).to receive(:new).with(physical_id).and_return(node)
      req
    end

    it 'should assign @attrs' do
      expect(assigns[:attrs]).to eq attrs
    end

    it 'should assign @current_attributes' do
      expect(assigns[:current_attributes]).to eq current_attr
    end
  end

  describe '#yum_update' do
    let(:security){'security'}
    let(:exec){'exec'}
    let(:req){put :yum_update, id: physical_id, infra_id: infra.id, security: security, exec: exec}

    before do
      allow_any_instance_of(NodesController).to receive(:exec_yum_update)
        .with(infra, physical_id, security=='security', exec=='exec')
      req
    end

    it 'status should be 202' do
      expect(response.status).to eq 202
    end

    it 'should render text' do
      expect(response.body).to eq I18n.t('nodes.msg.yum_update_started')
    end
  end
end
