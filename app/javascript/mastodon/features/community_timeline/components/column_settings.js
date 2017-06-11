import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';
import ColumnCollapsable from '../../../components/column_collapsable';
import SettingToggle from '../../notifications/components/setting_toggle';
import SettingText from '../../../components/setting_text';

const messages = defineMessages({
  filter_regex: { id: 'home.column_settings.filter_regex', defaultMessage: 'Filter out by regular expressions' },
  settings: { id: 'home.settings', defaultMessage: 'Column settings' },
});

class ColumnSettings extends React.PureComponent {

  static propTypes = {
    settings: ImmutablePropTypes.map.isRequired,
    onChange: PropTypes.func.isRequired,
    onSave: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  render () {
    const { settings, onChange, onSave, intl } = this.props;

    return (
      <div>
        <span className='column-settings__section'><FormattedMessage id='home.column_settings.advanced' defaultMessage='Advanced' /></span>

        <div className='column-settings__row'>
          <SettingToggle settings={settings} settingKey={['regex', 'mode']} onChange={onChange} label={<FormattedMessage id='column_settings.regex_mode' defaultMessage='Search mode' />} />
        </div>

        <div className='column-settings__row'>
          <SettingText settings={settings} settingKey={['regex', 'body']} onChange={onChange} label={intl.formatMessage(messages.filter_regex)} />
        </div>
      </div>
    );
  }

}

export default injectIntl(ColumnSettings);
