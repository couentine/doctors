/*
 Copyright 2016 Google Inc. All Rights Reserved.
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
*/

this.workbox = this.workbox || {};
(function (exports) {
'use strict';

class ErrorFactory$1{constructor(a){this._errors=a;}createError(a,b){if(!(a in this._errors))throw new Error(`Unable to generate error '${a}'.`);let c=this._errors[a].replace(/\s+/g,' '),d=null;b&&(c+=` [${b.message}]`,d=b.stack);const e=new Error;return e.name=a,e.message=c,e.stack=d,e}}

const errors={"channel-name-required":`The channelName parameter is required when
    constructing a new BroadcastCacheUpdate instance.`,"responses-are-same-parameters-required":`The first, second, and
    headersToCheck parameters must be valid when calling responsesAreSame()`};var ErrorFactory = new ErrorFactory$1(errors);

var ErrorStackParser = {parse:()=>[]};

function isInstance(a,b){const c=Object.keys(a).pop();a[c]instanceof b||throwError(`The '${c}' parameter must be an instance of
      '${b.name}'`);}function isType(a,b){const c=Object.keys(a).pop(),d=typeof a[c];d!==b&&throwError(`The '${c}' parameter has the wrong type. (Expected:
      ${b}, actual: ${d})`);}function throwError(a){a=a.replace(/\s+/g,' ');const b=new Error(a);b.name='assertion-failed';const c=ErrorStackParser.parse(b);throw 3<=c.length&&(b.message=`Invalid call to ${c[2].functionName}() — `+a),b}

const cacheUpdatedMessageType='CACHE_UPDATED';
const defaultHeadersToCheck=['content-length','etag','last-modified'];
const defaultSource='workbox-broadcast-cache-update';

function broadcastUpdate({channel:a,cacheName:b,url:c,source:d}={}){isInstance({channel:a},BroadcastChannel),isType({cacheName:b},'string'),isType({source:d},'string'),isType({url:c},'string'),a.postMessage({type:cacheUpdatedMessageType,meta:d,payload:{cacheName:b,updatedUrl:c}});}

class LogGroup{constructor(){this._logs=[],this._childGroups=[],this._isFallbackMode=!1;const a=/Firefox\/(\d*)\.\d*/.exec(navigator.userAgent);if(a)try{const b=parseInt(a[1],10);55>b&&(this._isFallbackMode=!0);}catch(a){this._isFallbackMode=!0;}/Edge\/\d*\.\d*/.exec(navigator.userAgent)&&(this._isFallbackMode=!0);}addPrimaryLog(a){this._primaryLog=a;}addLog(a){this._logs.push(a);}addChildGroup(a){0===a._logs.length||this._childGroups.push(a);}print(){return 0===this._logs.length&&0===this._childGroups.length?void this._printLogDetails(this._primaryLog):void(this._primaryLog&&(this._isFallbackMode?this._printLogDetails(this._primaryLog):console.groupCollapsed(...this._getLogContent(this._primaryLog))),this._logs.forEach((a)=>{this._printLogDetails(a);}),this._childGroups.forEach((a)=>{a.print();}),this._primaryLog&&!this._isFallbackMode&&console.groupEnd())}_printLogDetails(a){const b=a.logFunc?a.logFunc:console.log;b(...this._getLogContent(a));}_getLogContent(a){let b=a.message;this._isFallbackMode&&'string'==typeof b&&(b=b.replace(/%c/g,''));let c=[b];return!this._isFallbackMode&&a.colors&&(c=c.concat(a.colors)),a.args&&(c=c.concat(a.args)),c}}

function isDevBuild(){return`dev`==`prod`}

self.workbox=self.workbox||{},self.workbox.LOG_LEVEL=self.workbox.LOG_LEVEL||{none:-1,verbose:0,debug:1,warn:2,error:3};const LIGHT_GREY=`#bdc3c7`; const DARK_GREY=`#7f8c8d`; const LIGHT_GREEN=`#2ecc71`; const LIGHT_YELLOW=`#f1c40f`; const LIGHT_RED=`#e74c3c`; const LIGHT_BLUE=`#3498db`;class LogHelper{constructor(){this._defaultLogLevel=isDevBuild()?self.workbox.LOG_LEVEL.debug:self.workbox.LOG_LEVEL.warn;}log(a){this._printMessage(self.workbox.LOG_LEVEL.verbose,a);}debug(a){this._printMessage(self.workbox.LOG_LEVEL.debug,a);}warn(a){this._printMessage(self.workbox.LOG_LEVEL.warn,a);}error(a){this._printMessage(self.workbox.LOG_LEVEL.error,a);}_printMessage(a,b){if(this._shouldLogMessage(a,b)){const c=this._getAllLogGroups(a,b);c.print();}}_getAllLogGroups(a,b){const c=new LogGroup,d=this._getPrimaryMessageDetails(a,b);if(c.addPrimaryLog(d),b.error){const a={message:b.error,logFunc:console.error};c.addLog(a);}const e=new LogGroup;if(b.that&&b.that.constructor&&b.that.constructor.name){const a=b.that.constructor.name;e.addLog(this._getKeyValueDetails('class',a));}return b.data&&('object'!=typeof b.data||b.data instanceof Array?e.addLog(this._getKeyValueDetails('additionalData',b.data)):Object.keys(b.data).forEach((a)=>{e.addLog(this._getKeyValueDetails(a,b.data[a]));})),c.addChildGroup(e),c}_getKeyValueDetails(a,b){return{message:`%c${a}: `,colors:[`color: ${LIGHT_BLUE}`],args:b}}_getPrimaryMessageDetails(a,b){let c,d;a===self.workbox.LOG_LEVEL.verbose?(c='Info',d=LIGHT_GREY):a===self.workbox.LOG_LEVEL.debug?(c='Debug',d=LIGHT_GREEN):a===self.workbox.LOG_LEVEL.warn?(c='Warn',d=LIGHT_YELLOW):a===self.workbox.LOG_LEVEL.error?(c='Error',d=LIGHT_RED):void 0;let e=`%c🔧 %c[${c}]`;const f=[`color: ${LIGHT_GREY}`,`color: ${d}`];let g;return'string'==typeof b?g=b:b.message&&(g=b.message),g&&(g=g.replace(/\s+/g,' '),e+=`%c ${g}`,f.push(`color: ${DARK_GREY}; font-weight: normal`)),{message:e,colors:f}}_shouldLogMessage(a,b){if(!b)return!1;let c=this._defaultLogLevel;return self&&self.workbox&&'number'==typeof self.workbox.logLevel&&(c=self.workbox.logLevel),c===self.workbox.LOG_LEVEL.none||a<c?!1:!0}}var logHelper = new LogHelper;

function responsesAreSame({first:a,second:b,headersToCheck:c}={}){if(!(a instanceof Response&&b instanceof Response&&c instanceof Array))throw ErrorFactory.createError('responses-are-same-parameters-required');const d=c.some((c)=>a.headers.has(c)&&b.headers.has(c));return d?c.every((c)=>a.headers.has(c)===b.headers.has(c)&&a.headers.get(c)===b.headers.get(c)):(logHelper.log({message:`Unable to determine whether the response has been updated
        because none of the headers that would be checked are present.`,data:{"First Response":a,"Second Response":b,"Headers To Check":JSON.stringify(c)}}),!0)}

class BroadcastCacheUpdate{constructor({channelName:a,headersToCheck:b,source:c}={}){if('string'!=typeof a||0===a.length)throw ErrorFactory.createError('channel-name-required');this.channelName=a,this.headersToCheck=b||defaultHeadersToCheck,this.source=c||defaultSource;}get channel(){return this._channel||(this._channel=new BroadcastChannel(this.channelName)),this._channel}notifyIfUpdated({first:a,second:b,cacheName:c,url:d}){isType({cacheName:c},'string'),responsesAreSame({first:a,second:b,headersToCheck:this.headersToCheck})||broadcastUpdate({cacheName:c,url:d,channel:this.channel,source:this.source});}}

class BroadcastCacheUpdatePlugin extends BroadcastCacheUpdate{cacheDidUpdate({cacheName:a,oldResponse:b,newResponse:c,url:d}){isType({cacheName:a},'string'),isInstance({newResponse:c},Response),b&&this.notifyIfUpdated({cacheName:a,first:b,second:c,url:d});}}

exports.BroadcastCacheUpdate = BroadcastCacheUpdate;
exports.BroadcastCacheUpdatePlugin = BroadcastCacheUpdatePlugin;
exports.broadcastUpdate = broadcastUpdate;
exports.cacheUpdatedMessageType = cacheUpdatedMessageType;
exports.responsesAreSame = responsesAreSame;

}((this.workbox.broadcastCacheUpdate = this.workbox.broadcastCacheUpdate || {})));
//# sourceMappingURL=workbox-broadcast-cache-update.prod.v2.0.3.js.map
