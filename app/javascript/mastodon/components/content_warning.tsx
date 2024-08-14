import { FormattedMessage } from 'react-intl';

export const ContentWarning: React.FC<{
  text: string;
  expanded?: boolean;
  onClick?: () => void;
}> = ({ text, expanded, onClick }) => (
  <div className='content-warning'>
    <div className='content-warning__border' />

    <div className='content-warning__body'>
      <p>{text}</p>
      <button className='link-button' onClick={onClick}>
        {expanded ? (
          <FormattedMessage
            id='content_warning.hide'
            defaultMessage='Hide post'
          />
        ) : (
          <FormattedMessage
            id='content_warning.show'
            defaultMessage='Show anyway'
          />
        )}
      </button>
    </div>

    <div className='content-warning__border' />
  </div>
);
