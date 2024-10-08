<master>
<property name="doc(title)">@title;literal@</property>
<property name="context">@context;literal@</property>

<h1>@title;noquote@</h1>
<p>
The current version of the @what@ is @version@.
<p>The directory @resource_prefix@ is <strong><if @writable;literal@ false>not</if> writable</strong> for the server.</p>

<if @jsFileExists@ false>
  <p>The JavaScript file <strong>@plainFile@</strong> does not exist on your system.
  You might consider to download it from @downloadURL@ and copy from the expanded folder
  the following files:
  <pre>
  cp boomerang-@version@/boomerang.js @resource_prefix@/boomerang-@version@.js
  cp -r boomerang-@version@/plugins @resource_prefix@/plugins-@version@
  </pre>
  </p>
</if>
<else>
<p>The JavaScript code of the @what@ is installed locally
under<br> <strong>@resource_prefix@</strong>.</p>
<if @compressedFile@ nil>
<p>
  The JavaScript file <strong>@jsFile@</strong> is not compressed. 
  <if @writable;literal@ true and @gzip;literal@ ne "">
    <p>Do you want to compress it now? <a href="compress" class="button">compress</a>
    </p>
  </if>
  <else>
    <p>The directory <strong>@resource_prefix@</strong> is
    NOT writable for the server. If you make it writable,
    you can compress the JavaScript file over this interface.</p>
  </else>
</if>
<else>
<p>There is a compressed version of <strong>@jsFile@</strong> that can be used for
delivery via NaviServer.
</else>
</else>
