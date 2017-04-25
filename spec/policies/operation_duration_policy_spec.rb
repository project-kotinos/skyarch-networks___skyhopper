#
# Copyright (c) 2013-2017 SKYARCH NETWORKS INC.
#
# This software is released under the MIT License.
#
# http://opensource.org/licenses/mit-license.php
#

require_relative '../spec_helper'

describe OperationDurationPolicy do
  subject{described_class}

  %i[create? upload_icalendar? show? show_icalendar?].each do |action|
    permissions action do
      context 'when allow' do
        let(:infra){create(:infrastructure)}
        let(:project){infra.project}
        let(:user){create(:user, projects: [project], master: false)}

        it 'should be permit' do
          is_expected.to permit(user, infra)
        end
      end

      context 'when not allow' do
        let(:user){create(:user, master: false)}
        let(:infra){create(:infrastructure)}
        it 'should not be permit' do
          is_expected.not_to permit(user, infra)
        end
      end
    end
  end


end
