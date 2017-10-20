import axios from 'axios'

export const TWEXILE_SUBSCRIBE_CHANGE = "TWEXILE_SUBSCRIBE_CHANGE"

export function changeTwexileStatus(getState) {
  return (dispatch, getState) => {
    var authorized = axios
      .get(`https://twexile.nayukana.info/authorize?token=${getState().getIn(['meta', 'access_token'])}`)
      .then(response => {
        return true;
      }).catch(response => {
        if (response.status == 302) {
          return response.headers['location']
        } else {
          return false;
        }
      });
    authorized.then(authorized => {
      if (typeof authorized === "string") {
        dispatch(openModal('CONFIRM', {
          message: <FormattedMessage id='confirmations.authorize.required.message' 
                                     defaultMessage='click this {link} and authorize with twitter'
                                     values={{ link: <a href={authorized}>link</a> }} />,
        }));
      } else if (authorized == false) {
        dispatch(openModal('CONFIRM', {
          message: <FormattedMessage id='confirmations.authorize.failure.message' 
                                     defaultMessage='authorization failed' />,
        }));
      } else {
        dispatch(openModal('CONFIRM', {
          message: <FormattedMessage id='confirmations.authorize.success.message' 
                                     defaultMessage='authorization success' />,
        }));
      }
    })
    return {
      type: TWEXILE_SUBSCRIBE_CHANGE
    };
  };
}