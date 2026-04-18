# Synthetic ONA Project Meeting
**Date:** 2026-04-14
**Speakers:** Curtis (Speaker 1), Sylvia (Speaker 2), Ivana (Speaker 3)
**Duration:** ~18 minutes
**Topic:** Synthetic ONA v3 handoff, scenario catalog, licensing, and project sustainability

---

[00:00:00.000 --> 00:00:02.420] **Curtis**: All right, now we're good, okay.
[00:00:03.240 --> 00:00:06.060] **Sylvia**: Hey, welcome to our audience tonight.
[00:00:09.940 --> 00:00:15.880] **Sylvia**: Guys, yeah, because I'll be away, I wanted to prepare a little bit of a hand-off documentation.
[00:00:16.840 --> 00:00:26.860] **Sylvia**: I wanted to implement a few more things in the data generation, and I'm still struggling with this. I'm getting a few bugs in the code, and I need to clean that up and then redo.
[00:00:27.960 --> 00:00:46.220] **Sylvia**: but in principle that these are the updates I will share my screen and show you so this is a this is a like a short PDF that sort of compares which is the short PDF 25 pages
[00:00:54.460 --> 00:01:30.500] **Sylvia**: I was thinking is that we do this scenario catalog with 10 benchmark scenarios and be replicated. And I will show you in a minute, we get the consultant demo, which is the one that you guys created, right? And that they involved in the code, then we have the privacy. So the first five are more related to different types of stakeholders. The latter five are more related to organizations, typically between 500 and 3000. So I wanted to create these scenarios
[00:01:30.500 --> 00:01:34.540] **Curtis**: that are very typical for them. Yeah, these are more like culture resets or other types of
[00:01:34.540 --> 00:01:52.020] **Sylvia**: Exactly. AI adoption, resizing, M&A, culture, succession planning, and so on. The other one is, you know, consultants, CHROs, organizational developers, researchers, and developers themselves. So, people want to build on top of what we already did.
[00:01:52.360 --> 00:01:53.700] **Ivana**: Right, right. Nice.
[00:01:53.960 --> 00:02:05.780] **Sylvia**: All right. So, yeah, this is just like, you know, technical stuff about what exactly we're We're building on the ontologies and the baseline models that we had in version one.
[00:02:06.700 --> 00:02:09.540] **Sylvia**: And we're just making them more complex basically in this version.
[00:02:09.900 --> 00:02:10.240] **Curtis**: Wonderful.
[00:02:12.240 --> 00:02:20.740] **Sylvia**: It has this like a very clear architecture of what's what, how do we count the nodes, the edges, what kinds of edges,
[00:02:22.080 --> 00:02:26.880] **Sylvia**: how do we replicate it? How do we validate it? It's all going to be there.
[00:02:27.700 --> 00:02:28.220] **Sylvia**: Great.
[00:02:28.860 --> 00:02:30.260] **Sylvia**: Basically, that's it. That's it.
[00:02:30.740 --> 00:02:32.060] **Ivana**: That's it. Oh, that's all.
[00:02:32.340 --> 00:02:34.160] **Curtis**: This is what she does on a weekend.
[00:02:35.060 --> 00:02:48.360] **Sylvia**: That's it. Yeah, the rest is just more technical information so that we can follow up nicely on them. Great. I will show you a little bit the-
[00:02:48.360 --> 00:02:53.660] **Curtis**: Yeah, show me where you're at on the actual code generation and some of the bugs you're hitting.
[00:02:53.660 --> 00:03:02.900] **Sylvia**: So this is the one, but I can knit this, but I have a bug in R actually here somewhere.
[00:03:04.000 --> 00:03:15.240] **Sylvia**: I need to check what this is. But in principle, it's just laying out what the code does with the new additions, comparing version two to version three.
[00:03:15.860 --> 00:03:19.100] **Sylvia**: This is the most important information so far.
[00:03:19.860 --> 00:03:24.940] **Sylvia**: is the scenario library, the segments, the temporal logic.
[00:03:25.680 --> 00:03:36.500] **Sylvia**: I wanted to have these two different ones like AI adoption and mergers and acquisitions. I want to specify them as temporal networks so we can take a look at how things change over time.
[00:03:38.000 --> 00:03:50.080] **Sylvia**: More industry realistic, you know, I included this directed because that was a note from the version two, I had only undirected while a lot of the ONA is directed, so it was important.
[00:03:50.340 --> 00:03:51.200] **Curtis**: Very, very important.
[00:03:51.200 --> 00:04:08.260] **Sylvia**: AI era modeling, again, more realistic to what's coming in the next years, benchmark outputs, and the part that can be included into the platform, into the visual platform.
[00:04:08.960 --> 00:04:35.460] **Sylvia**: The rest is not, you know, it's just like, the code itself, this is the same, same, I wanted to jump to building blocks, this is the same.
[00:04:39.760 --> 00:04:42.280] **Sylvia**: The topology selection is the same.
[00:04:42.820 --> 00:04:44.260] **Sylvia**: These are the edge types.
[00:04:44.440 --> 00:04:45.460] **Curtis**: Yeah, okay.
[00:04:46.780 --> 00:04:47.500] **Sylvia**: Great, trust me.
[00:04:48.020 --> 00:04:49.520] **Sylvia**: Communication, collaboration, trust, advice.
[00:04:49.720 --> 00:04:51.780] **Curtis**: That's a great starting point. Sure, right.
[00:04:52.440 --> 00:04:54.220] **Sylvia**: Innovation, decision, influence.
[00:04:54.480 --> 00:04:59.720] **Curtis**: I like tool interaction because does that include agent to agent, human to agent, all those kinds of interactions?
[00:05:00.680 --> 00:05:10.680] **Sylvia**: Okay. Yes, exactly, exactly. That's specifically what I wanted to do because I wanted to address these upcoming issues that organizations will have.
[00:05:11.180 --> 00:05:15.240] **Sylvia**: All right, business questions related to each scenario.
[00:05:16.000 --> 00:05:18.140] **Curtis**: Wow, okay, great.
[00:05:20.340 --> 00:05:25.060] **Sylvia**: For example, for resizing what breaks or overloads when the organization is delayed or right-sized.
[00:05:26.580 --> 00:05:27.660] **Sylvia**: For mergers and acquisitions,
[00:05:28.240 --> 00:05:37.300] **Sylvia**: how have two organizations actually integrated after the acquisition for culture? is culture change, altering real collaboration and trust patterns, et cetera.
[00:05:37.960 --> 00:05:38.680] **Ivana**: Great. Okay.
[00:05:39.940 --> 00:05:44.340] **Sylvia**: All right. And then these are validations and stuff for all of them.
[00:05:45.580 --> 00:05:49.960] **Curtis**: Just for my geeky pleasure, go back to RStudio, because I've never seen RStudio.
[00:05:50.880 --> 00:05:53.900] **Curtis**: What is this planet you're living on?
[00:05:54.560 --> 00:06:05.180] **Sylvia**: Well, it's very, very much similar to Python, basically. I like to work in RMarkdown, because our markdown allows me to have this kind of HTML file.
[00:06:05.180 --> 00:06:09.040] **Curtis**: I see that. You get that nice HTML kind of rendered, structured.
[00:06:09.660 --> 00:06:21.300] **Sylvia**: Exactly, where I can jump to different sections and I can even hide the code or show all the code, and then I can share this with more non-technical people, and I really like this about it.
[00:06:21.300 --> 00:06:23.920] **Curtis**: Yeah, just documentation comes along for the ride, yeah?
[00:06:24.700 --> 00:06:30.920] **Sylvia**: Exactly, exactly. And then here is basically the back end of that.
[00:06:32.300 --> 00:06:44.900] **Sylvia**: You can run the codes in chunks, which is great, because then, you know, whenever you have like a small error or something, you can, you know, manually, like, you know, fix it.
[00:06:45.540 --> 00:06:48.060] **Sylvia**: You don't have to re redo the entire code.
[00:06:49.200 --> 00:06:56.540] **Ivana**: We both have R and Python, because I know R is more in academics. I actually don't know why this is Python is more industry.
[00:06:57.060 --> 00:06:58.820] **Curtis**: Yeah, yeah, it's great. That's why we chose both.
[00:07:00.120 --> 00:07:00.740] **Ivana**: That's exactly exactly.
[00:07:00.740 --> 00:07:27.480] **Sylvia**: me. So this is this is what it is. And I actually got into visual code, thanks to you, Ivana from last time. Now I'm using it because with the cloud code and with chat GPT and all of that, I can now generate Python codes and I can visualize and I don't I don't I'm not fluent in Python. But I'm, you know, I'm trying to learn actually this way, because I can visualize the code and the structure and everything.
[00:07:28.720 --> 00:07:32.060] **Ivana**: If you know R, Python will be a bruise for you.
[00:07:32.800 --> 00:07:34.600] **Ivana**: And that's what I'm hearing.
[00:07:34.940 --> 00:07:35.760] **Sylvia**: Yes, that's what I'm hearing.
[00:07:36.600 --> 00:07:38.400] **Ivana**: Python is like. Yeah.
[00:07:40.420 --> 00:07:40.980] **Ivana**: That's great.
[00:07:41.880 --> 00:07:52.560] **Curtis**: So Sylvia, when you finally hand us the package, what's this folder structure like there? It was like, is it nested folders or is just one big file or how are you will hand the actual project files over?
[00:07:54.340 --> 00:08:19.360] **Sylvia**: That's what I'm thinking. I do want to have like one single folder with everything in there. Yeah, it's called the implementation package. I actually managed to do so. Yeah, I went back and forth today basically with the scenarios and stuff like that, but I managed to get one ready. Now I will update it with the latest scenarios and I will hand out
[00:08:20.500 --> 00:08:31.480] **Sylvia**: the folder with all the dependents. Okay, all right. But it's going to be R, yeah. So that's great, that's great. I know you've got a
[00:08:31.480 --> 00:08:54.520] **Curtis**: couple bugs still, but if you could give me the preliminary handover, there's, let me share a screen and I'll show you what the document, I want to update because it's an important one that keeps our two working teams sort of linked and sort of playing off the same sheet. We created this, you remember this one, that was kind of, when we rendered it, it looked kind of like a radial wheel, but it was all the structured metadata about our project.
[00:08:55.320 --> 00:09:05.300] **Curtis**: And now that you've got these, for example, just on the 10 key scenarios, the top five being kind of role-based and the bottom five being business, I wanna update this. This is our ground.
[00:09:05.540 --> 00:09:07.620] **Ivana**: I actually use this one as my code.
[00:09:08.180 --> 00:09:08.340] **Ivana**: Right, right.
[00:09:08.860 --> 00:09:13.040] **Curtis**: Okay, great. So like now you have an updated version of this because this one's stale, right?
[00:09:13.660 --> 00:09:34.680] **Curtis**: So I wanna have a kind of grounding document because for the other team that's doing the visualization and the fun graphs and all making you know making graphs come to life and animating them and blah blah blah blah all that stuff we're doing in we call it project Prometheus you're Hephaestus by the way you're the Greek the Greek goddess Hephaestus yes you're down in the forge hammering out the R code
[00:09:37.580 --> 00:09:42.640] **Curtis**: okay yes so but that's going to keep us all linked so team Prometheus and team Hephaestus
[00:09:42.640 --> 00:09:49.440] **Ivana**: are playing off the same same stuff right yeah okay so yeah we'll need i think with
[00:09:49.440 --> 00:09:59.860] **Curtis**: your whole package and even if it's just again an interim deliverable and you got a few bugs to fix that's fine because that way you'll unblock our other team that wants to get busy on the viz stuff
[00:09:59.860 --> 00:10:09.280] **Sylvia**: right yes yes yes that's my hope so hopefully i'm gonna finish this today okay and then wish you luck
[00:10:12.160 --> 00:10:31.500] **Curtis**: i won't but i mean just i'm serious like you don't have to finish it you can give it right now and there'd be tremendous amount of value. We will just keep going and you can roll in your updates later. That works just as well. That's what I'm saying. Okay. So, all right. Okay. But if you want to give yourself that time constraint and it's going to make you sit down and do it,
[00:10:31.560 --> 00:10:36.360] **Ivana**: then go for it, right? Have fun. Well, because otherwise, you know, with like the small,
[00:10:36.860 --> 00:10:40.740] **Sylvia**: you know, tweaks and stuff that I need to do, if I do it like three weeks from now,
[00:10:40.840 --> 00:10:44.440] **Curtis**: I'm going to finish the whole thing. Exactly. You'll lose your own mental context, right?
[00:10:44.880 --> 00:10:47.880] **Sylvia**: Yeah, now I want to finish this and then move to the next one.
[00:10:48.440 --> 00:10:53.080] **Curtis**: Yeah, hear you, hear you. Cool. Ivana, what do you think of this thing she just showed?
[00:10:54.160 --> 00:11:11.740] **Ivana**: It's amazing. Yeah, it's really impressive. I know R code and Python for things like analyzing data. You know what I mean? Give me a data set, I can analyze it kind of thing, but that's the building stuff. That's not my wheelhouse, so it's really impressive. that was really cool.
[00:11:12.820 --> 00:11:30.460] **Sylvia**: Actually, maybe I need to talk to you about that. On the 20th, so next week I have a workshop for the methods first network, which is a network of international, generally scholars who work on different methods applied in different ways.
[00:11:30.980 --> 00:11:44.960] **Sylvia**: And I proposed an open workshop on using AI I basically to build platforms and stuff like that. And I will showcase this project if you don't mind.
[00:11:45.840 --> 00:11:46.420] **Ivana**: Yeah, sure.
[00:11:46.860 --> 00:11:50.880] **Sylvia**: The workshop is actually, I mean, if it's in your time zone or something, you can even, you know.
[00:11:51.000 --> 00:11:56.640] **Curtis**: Oh yeah, push that to Slack. Would you just mention what you just said on Slack and let people know that they could come and join? That would be great.
[00:11:57.240 --> 00:11:57.840] **Sylvia**: Yeah, yeah, yeah.
[00:11:57.840 --> 00:12:02.680] **Ivana**: It's a free event. It's in the afternoon and people can come up
[00:12:02.680 --> 00:12:04.440] **Sylvia**: with all sorts of stuff. Nice.
[00:12:05.220 --> 00:12:13.340] **Sylvia**: For me, it's more like, let's see what we all are doing about this about you know how people will use
[00:12:13.340 --> 00:12:37.400] **Curtis**: it afterwards on that let's just close on that and I'm still recording I'd love to kind of get first your take Sylvia now that you're in it you're working with it you see this thing coming to life we're actually gonna deliver it's actually gonna happen okay there's gonna be this github repository like think like futurist like what are they gonna be the second and third order effects imagine this thing gets adopted and it's getting used both in corporates and NGOs,
[00:12:38.560 --> 00:12:43.040] **Curtis**: schools, like where you teach. What do you see happening with our code? What do you think is
[00:12:43.040 --> 00:13:09.660] **Sylvia**: going to... What are the impacts we're going to have? Well, I think a lot of it, like 80% of it, will be used through the interface just to play around and show things in real time. When you have a discussion, a conversation, you want to demo something. I think most of the use cases will be around that and then you will have 20% of people who will be curious to maybe build something on top or just like take a look you know under the hood what's how this has been
[00:13:09.660 --> 00:13:31.960] **Curtis**: you know worked up yeah yeah as you as you mention it in the talk you're giving it'll be interesting just to measure people's reactions and people going oh where can I sign up to that that will be an indicator for us of interest you know yeah agreed yeah yeah what do you think Ivana, this thing gonna have legs? Is this gonna take over the world?
[00:13:34.440 --> 00:13:45.280] **Ivana**: Yeah, it's awesome. I think, yeah, I think it'll be really beneficial to a lot of different types of people, you know, the CHROs, the academics, the students, the, you know.
[00:13:46.260 --> 00:13:46.780] **Curtis**: The nerds.
[00:13:46.860 --> 00:13:50.720] **Sylvia**: So I see three elements, right? That were four, maybe four elements.
[00:13:50.720 --> 00:13:51.240] **Ivana**: Nerds, the jocks.
[00:13:52.080 --> 00:14:14.640] **Sylvia**: Yeah, it's the code that generates database. database, it's the actual PDFs with the business cases that people will read or whatever form we put it in, like PowerPoints or whatever, or maybe a site or something like that. It's the interface that people will work with. And no, I think these are the three elements.
[00:14:14.920 --> 00:14:19.000] **Curtis**: Yeah. Well, and the visualization tools where they're going to see these animations, right? That's what we're working on.
[00:14:19.280 --> 00:14:21.000] **Sylvia**: Yeah, yeah, but that's in the platform, right?
[00:14:21.100 --> 00:14:21.520] **Curtis**: Right, right, exactly.
[00:14:21.940 --> 00:14:23.360] **Sylvia**: I mean, we'll be doing the implementation.
[00:14:23.360 --> 00:14:30.160] **Curtis**: A lot of it. Well, yeah, we're all we he'll be leading team Prometheus, but we're all gonna be getting in there and putting our mix. Yeah
[00:14:30.160 --> 00:14:36.880] **Sylvia**: Yeah, exactly. Yeah. Mm-hmm. I think that'll be a huge part of the success of this, right?
[00:14:37.480 --> 00:14:39.520] **Curtis**: Yeah, yeah, it's gonna really make it come to life
[00:14:40.240 --> 00:14:43.880] **Curtis**: One other last question before we maybe close it out. We can finish early today
[00:14:44.940 --> 00:15:07.320] **Curtis**: The question about the license the create whether it's creative Commons or MIT the most common I see is MIT license which just says hey free software do whatever you want with it but just include a reference you know it's just like a small little attribution. Does that feel like the appropriate license to use in a case like this? Is there any reason we would use another one? Do you
[00:15:07.320 --> 00:15:17.540] **Sylvia**: have any thoughts Sylvia? I think it's good like this simply because this is also like an educational tool as well right so I think in a way it's good to
[00:15:18.680 --> 00:15:29.740] **Sylvia**: have, how do you say, reference people behind it. I think it gives it credibility and all of that.
[00:15:32.240 --> 00:15:35.100] **Sylvia**: So yeah, I would go for attribution, yes.
[00:15:35.480 --> 00:16:03.200] **Curtis**: I would show you the way it would ultimately look. I don't, let me just share a screen here for a sec. I kind of mocked it up, played it out. Like, here's all my crazy projects. but like the one I put up was where is it Jedi dojo and a claw there it is I'm staring right at it okay so so the license might look something like this
[00:16:05.820 --> 00:16:27.380] **Curtis**: it could be that you know if it's creative Commons but this is the thing we want to keep a reference back to the community. That would be the point, right? You're free to share, copy, and redistribute. Adapt, remix under the following terms. Attribution. You must give appropriate credit to the network first manifesto community. Provide a link to the license.
[00:16:27.940 --> 00:16:51.460] **Curtis**: Indicative changes were made. Now, some people won't do it. That's fine, but I mean, I think this is just the baseline. This is the CC Creative Commons and there's MIT. They're very similar. MIT license is quite a similar one. For some reason, Francisco wasn't sure about that. He didn't feel super confident about either way. He just said, just put it out there, don't attach any license at all. But the
[00:16:52.340 --> 00:16:56.880] **Ivana**: whole point is that we're trying to get Network First Manifesto out there.
[00:16:57.180 --> 00:17:38.520] **Curtis**: I don't wanted to do that. I'm assuming that the NFM is not a flash in the pan. It's gonna be real, it's gonna go on. And the other role we have to consider is we will be the maintainers. Like if this lands on a GitHub site, someone has a login to that site and when people fork the code and they give back a change, they're basically giving back a change to us saying, hey here's an improvement I made, right? So and to incorporate that, someone on our side has to be the maintainer, the one that decides do we want to roll that in or not. That means we have like an ongoing mission here, like if this thing has legs, that's what it means. So we have to think about this, like who's going to do that. And that does beg a big question. Who will do this? Who will be the maintainers?
[00:17:39.140 --> 00:17:43.460] **Curtis**: These are questions I want to get in now and not like get to the end and go, uh-oh, uh-oh,
[00:17:43.460 --> 00:17:55.900] **Sylvia**: we're hitting a big question mark. Oh, absolutely. I mean, a lot of these very nice projects sort of eventually fail because interest in them fades on the maintenance side, not necessarily on the
[00:17:56.680 --> 00:18:01.220] **Sylvia**: Yeah. And yeah, absolutely. We have to think about these in advance.
[00:18:02.160 --> 00:18:06.360] **Curtis**: Yeah. Okay. Just want to keep that in the room. We don't have to answer it today, but thank you.
[00:18:06.960 --> 00:18:14.460] **Curtis**: Okay. All right. Hey, I think that's a perfect meeting. We can close early, unless there's anything else, because I want to give Sylvia time to go fix those bugs.
[00:18:15.300 --> 00:18:20.660] **Ivana**: Yep. Okay. Well, that's good on my part. Thank you. Thank you.
[00:18:22.240 --> 00:18:24.660] **Ivana**: All right. Ciao. Bye. Bye. See you.
[00:18:25.160 --> 00:18:25.340] **Ivana**: See you.
