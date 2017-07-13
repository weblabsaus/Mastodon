import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import ImmutablePureComponent from 'react-immutable-pure-component';

import ReactSwipeableViews from 'react-swipeable-views';
import { links, getIndex, getLink } from './tabs_bar';

import BundleContainer from '../containers/bundle_container';
import ColumnLoading from './column_loading';
import BundleColumnError from './bundle_column_error';
import { Compose, Notifications, HomeTimeline, CommunityTimeline, PublicTimeline, HashtagTimeline } from '../../ui/util/async-components';

const componentMap = {
  'COMPOSE': Compose,
  'HOME': HomeTimeline,
  'NOTIFICATIONS': Notifications,
  'PUBLIC': PublicTimeline,
  'COMMUNITY': CommunityTimeline,
  'HASHTAG': HashtagTimeline,
};

export default class ColumnsArea extends ImmutablePureComponent {

  static contextTypes = {
    router: PropTypes.object.isRequired,
  };

  static propTypes = {
    columns: ImmutablePropTypes.list.isRequired,
    singleColumn: PropTypes.bool,
    children: PropTypes.node,
  };

  state = {
    pendingIndex: null,
  }

  handleSwipe = (index) => {
    this.setState({ pendingIndex: index });
  }

  handleAnimationEnd = () => {
    if (this.state.pendingIndex !== null) {
      this.context.router.history.push(getLink(this.state.pendingIndex));
      this.setState({ pendingIndex: null });
    }
  }

  renderView = (link, index) => {
    const columnIndex = getIndex(this.context.router.history.location.pathname);
    const title = link.props.children[1] && React.cloneElement(link.props.children[1]);
    const icon = (link.props.children[0] || link.props.children).props.className.split(' ')[2].split('-')[1];

    const view = (index === columnIndex) ?
      React.cloneElement(this.props.children) :
      <ColumnLoading title={title} icon={icon} />;

    return (
      <div className='columns-area' key={index}>
        {view}
      </div>
    );
  }

  renderLoading = () => {
    return <ColumnLoading />;
  }

  renderError = (props) => {
    return <BundleColumnError {...props} />;
  }

  render () {
    const { columns, children, singleColumn } = this.props;
    const { pendingIndex } = this.state;

    const columnIndex = getIndex(this.context.router.history.location.pathname);

    if (singleColumn) {
      return columnIndex !== -1 ? (
        <ReactSwipeableViews index={columnIndex} onChangeIndex={this.handleSwipe} onTransitionEnd={this.handleAnimationEnd} animateTransitions={pendingIndex !== null} springConfig={{ duration: '400ms', delay: '0s', easeFunction: 'ease' }} style={{ height: '100%' }}>
          {links.map(this.renderView)}
        </ReactSwipeableViews>
      ) : <div className='columns-area'>{children}</div>;
    }

    return (
      <div className='columns-area'>
        {columns.map(column => {
          const params = column.get('params', null) === null ? null : column.get('params').toJS();

          return (
            <BundleContainer key={column.get('uuid')} fetchComponent={componentMap[column.get('id')]} loading={this.renderLoading} error={this.renderError}>
              {SpecificComponent => <SpecificComponent columnId={column.get('uuid')} params={params} multiColumn />}
            </BundleContainer>
          );
        })}

        {React.Children.map(children, child => React.cloneElement(child, { multiColumn: true }))}
      </div>
    );
  }

}
