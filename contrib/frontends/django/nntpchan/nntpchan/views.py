from django.conf import settings
from django.http import HttpResponse, HttpResponseNotAllowed, JsonResponse
from django.views.decorators.csrf import csrf_exempt   

from .frontend.models import Post, Attachment, Newsgroup
from .frontend import util

from . import thumbnail

import email
import traceback
from datetime import datetime
import mimetypes
import os

@csrf_exempt
def webhook(request):
    """
    endpoint for nntpchan daemon webhook
    """
    if request.method != 'POST':
        return HttpResponseNotAllowed(['POST'])
    
    try:
        msg = email.message_from_bytes(request.body)
        newsgroup = msg.get('Newsgroups')

        if newsgroup is None:
            raise Exception("no newsgroup specified")
        
        if not util.newsgroup_valid(newsgroup):
            raise Exception("invalid newsgroup name")
        
        bump = True
        group, created = Newsgroup.objects.get_or_create(name=newsgroup)
        if created:
            group.save()
        if group.banned:
            raise Exception("newsgroup is banned")

        msgid = None
        for h in ('Message-ID', 'Message-Id', 'MessageId', 'MessageID'):
            if h in msg:
                msgid = msg[h]
                break
        # check for sage
        if 'X-Sage' in msg and msg['X-Sage'] == '1':
            bump = False
            
        if msgid is None:
            raise Exception("no message id specified")
        elif not util.msgid_valid(msgid):
            raise Exception("invalid message id format: {}".format(msgid))

        opmsgid = msgid
        
        h = util.hashid(msgid)
        atts = list()
        ref = msg['References'] or ''
        posted = util.time_int(email.utils.parsedate_to_datetime(msg['Date']))

        if len(ref) > 0:
            opmsgid = ref
        
        f = msg['From'] or 'anon <anon@anon>'
        name = email.utils.parseaddr(f)[0]
        post, created = Post.objects.get_or_create(defaults={
            'posthash': h,
            'reference': ref,
            'posted': posted,
            'last_bumped': 0,
            'name': name,
            'subject': msg["Subject"] or '',
            'newsgroup': group}, msgid=msgid)
        m = ''

        for part in msg.walk():
            ctype = part.get_content_type()
            if ctype.startswith("text/plain"):
                m += '{} '.format(part.get_payload(decode=True).decode('utf-8'))
            else:
                payload = part.get_payload(decode=True)
                if payload is None:
                    continue
                filename = part.get_filename()
                mtype = part.get_content_type()
                ext = filename.split('.')[-1]
                fh = util.hashfile(bytes(payload))
                fn = fh + '.' + ext
                fname = os.path.join(settings.MEDIA_ROOT, fn)
                if not os.path.exists(fname):
                    with open(fname, 'wb') as f:
                        f.write(payload)
                tname = os.path.join(settings.MEDIA_ROOT, 'thumb-{}.jpg'.format(fn))
                placeholder = os.path.join(settings.ASSETS_ROOT, 'placeholder.jpg')
                if not os.path.exists(tname):
                    thumbnail.generate(fname, tname, placeholder)
                        
                att = Attachment(filehash=fh)
                att.mimetype = mtype
                att.filename = filename
                att.save()
                atts.append(att)
        post.message = m
        post.save()

        for att in atts:
            post.attachments.add(att)

            
        op, _ = Post.objects.get_or_create(defaults={
            'posthash': util.hashid(opmsgid),
            'reference': '',
            'posted': 0,
            'last_bumped': 0,
            'name': 'OP',
            'subject': 'OP Not Found',
            'newsgroup': group}, msgid=opmsgid)
        if bump:
            op.bump()
        op.save()
            
    except Exception as ex:
        traceback.print_exc()
        return JsonResponse({ 'error': '{}'.format(ex) })
    else:
        return JsonResponse({'posted': True})
